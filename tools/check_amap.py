#!/usr/bin/env python3
"""诊断高德 Key：仅 Python 标准库，不打印凭据或请求 URL。"""
import argparse
import json
import math
import os
from pathlib import Path
import re
import socket
import urllib.error
import urllib.parse
import urllib.request


HINTS = {
    '10001': 'Key 不正确或已过期：核对后端使用的 Key。',
    '10002': '没有此服务权限或接口路径错误：检查 Web 服务权限。',
    '10003': '日调用量超限：检查该服务额度。',
    '10004': '调用频率超限：稍后重试。',
    '10005': 'IP 白名单不匹配：检查后端实际出口 IP。',
    '10009': 'Key 平台不匹配：需要 Web 服务类型 Key。',
}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def load_config(path):
    values = {}
    if path.exists():
        for line in path.read_text(encoding='utf-8').splitlines():
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '=' not in line:
                raise ValueError('配置文件存在无等号的行')
            name, value = line.split('=', 1)
            name = name.strip()
            if name.startswith('export '):
                name = name[7:]
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                value = value[1:-1]
            values.setdefault(name, value)
    return {name: os.environ.get(name, values.get(name, default)) for name, default in (
        ('AMAP_API_KEY', ''), ('AMAP_BASE_URL', 'https://restapi.amap.com'))}


def request(opener, base, key, path, params):
    query = urllib.parse.urlencode(dict(params, key=key, output='JSON'))
    try:
        with opener.open(base.rstrip('/') + path + '?' + query, timeout=10) as response:
            body = response.read(1024 * 1024 + 1)
        if len(body) > 1024 * 1024:
            raise ValueError()
        data = json.loads(body)
        if not isinstance(data, dict):
            raise ValueError()
    except urllib.error.HTTPError as exc:
        return None, 'HTTP %d：检查网关/服务；重定向不会被跟随。' % exc.code
    except (urllib.error.URLError, TimeoutError, socket.timeout, OSError):
        return None, '网络/DNS/TLS/代理或超时错误，无法据此判断 Key 是否有效。'
    except (ValueError, UnicodeError):
        return None, '响应不是有效 JSON 对象或响应过大。'
    code = str(data.get('infocode', ''))
    if data.get('status') != '1' or code != '10000':
        safe_code = code if re.fullmatch(r'\d{5}', code) else '未知'
        return None, 'infocode=%s：%s' % (safe_code, HINTS.get(code, '查高德错误码文档，检查权限、额度、签名或参数。'))
    return data, 'infocode=10000，鉴权和本次接口调用成功。'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--env-file', type=Path, default=Path(__file__).resolve().parents[1] / 'server/.env')
    parser.add_argument('--longitude', type=float, default=116.397, help='GPS 经度，默认北京公开示例点')
    parser.add_argument('--latitude', type=float, default=39.908, help='GPS 纬度')
    args = parser.parse_args(argv)
    if not (math.isfinite(args.longitude) and math.isfinite(args.latitude)
            and -180 <= args.longitude <= 180 and -90 <= args.latitude <= 90):
        parser.error('经纬度无效')
    try:
        config = load_config(args.env_file)
    except (OSError, UnicodeError, ValueError):
        print('FAIL：配置文件无法读取或格式错误。')
        return 2
    key = config['AMAP_API_KEY']
    if not key.strip():
        print('FAIL：未配置 AMAP_API_KEY；环境变量（包括空值）优先于文件。')
        return 2
    # 防止配置错误时把 Key 发往未知主机；不输出完整配置。
    if config['AMAP_BASE_URL'].rstrip('/') != 'https://restapi.amap.com':
        print('FAIL：AMAP_BASE_URL 不是官方 HTTPS 地址，请核对配置。')
        return 2
    print('Key 已读取（不显示）；环境变量优先。请在后端所在机器执行以核对出口 IP 限制。')
    opener = urllib.request.build_opener(NoRedirect())
    failed = False

    def probe(label, path, params):
        nonlocal failed
        data, message = request(opener, config['AMAP_BASE_URL'], key, path, params)
        print(('%s：' % label) + ('PASS ' if data is not None else 'FAIL ') + message)
        failed = failed or data is None
        return data

    converted = probe('坐标转换', '/v3/assistant/coordinate/convert', {
        'locations': '%.3f,%.3f' % (args.longitude, args.latitude), 'coordsys': 'gps'})
    adcode = None
    if converted is not None:
        location = converted.get('locations', '')
        if isinstance(location, str) and re.fullmatch(r'-?\d+(?:\.\d+)?,-?\d+(?:\.\d+)?', location):
            lon, lat = map(float, location.split(','))
            address = probe('逆地理编码', '/v3/geocode/regeo', {
                'location': '%.3f,%.3f' % (lon, lat), 'extensions': 'base'})
            try:
                adcode = address['regeocode']['addressComponent']['adcode']
            except (TypeError, KeyError):
                pass
        if not isinstance(adcode, str) or not re.fullmatch(r'[1-9]\d{5}', adcode):
            failed = True
            adcode = None
            print('FAIL：无法从坐标链路取得有效行政区编码。')
    if adcode is None:
        print('天气独立使用北京示例行政区；用于区分天气权限与定位服务权限。')
        adcode = '110101'
    for label, extension, field in [('实况天气', 'base', 'lives'), ('天气预报', 'all', 'forecasts')]:
        data = probe(label, '/v3/weather/weatherInfo', {'city': adcode, 'extensions': extension})
        if data is not None and (not isinstance(data.get(field), list) or not data[field]):
            failed = True
            print('FAIL：接口鉴权成功，但天气列表为空或格式异常。')
    print('存在失败，请按对应步骤排查。' if failed else
          '全部通过：本次未发现 Key/服务权限问题；若 App 仍失败，检查运行进程配置、天气时效校验与超时。')
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
