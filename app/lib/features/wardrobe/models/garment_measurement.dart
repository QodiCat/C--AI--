class GarmentMeasurement {
  const GarmentMeasurement(
      this.key, this.label, this.method, this.purpose, this.group);
  final String key, label, method, purpose, group;
}

const garmentMeasurements = [
  GarmentMeasurement(
      'length', '衣长', '从肩颈交点垂直量到下摆', '判断下摆在腰、胯还是臀部，是否适合塞裤腰', 'top'),
  GarmentMeasurement(
      'shoulderWidth', '肩宽', '后背平铺，两侧肩袖接缝顶点直量', '判断合肩还是落肩', 'top'),
  GarmentMeasurement(
      'chest', '胸围', '两侧腋下接缝横量，平铺宽乘 2', '判断胸背松紧、衬衫是否绷扣及叠穿空间', 'top'),
  GarmentMeasurement('waist', '腰围', '上衣在收腰处横量；裤子扣好纽扣拉好拉链，腰头横量；平铺宽乘 2',
      '判断腰部松紧；比较裤子时选择相近腰高', 'both'),
  GarmentMeasurement('hem', '下摆围', '下摆横量，平铺宽乘 2', '判断是否卡胯臀、抬手是否上窜', 'top'),
  GarmentMeasurement(
      'sleeveLength', '袖长', '肩袖接缝顶点沿袖子外侧量到袖口', '判断袖口在手腕还是手背', 'top'),
  GarmentMeasurement(
      'centerBackSleeve', '连肩袖长', '从后领中心经肩部沿袖子外侧量到袖口', '落肩、插肩款优先比较袖口落点', 'top'),
  GarmentMeasurement(
      'upperArm', '上臂围／袖肥', '腋下接缝附近垂直于袖长横量，平铺宽乘 2', '判断大臂及叠穿是否紧', 'top'),
  GarmentMeasurement(
      'armholeDepth', '袖窿深', '肩袖接缝顶点垂直量到腋下接缝水平线', '判断夹腋及抬手带起衣身的可能', 'top'),
  GarmentMeasurement(
      'backWidth', '背宽', '后片同一高度横量两侧袖窿缝之间距离，并记录高度', '判断前伸、抱臂时后背是否紧', 'top'),
  GarmentMeasurement('cuff', '袖口围', '袖口扣好或自然放平，横量乘 2', '判断手能否穿过及是否贴腕', 'top'),
  GarmentMeasurement(
      'collar', '领围', '沿衬衫领座内侧，从领扣中心量到扣眼中心', '判断扣上最上面扣子后是否舒服', 'top'),
  GarmentMeasurement('neckWidth', '领宽', '两侧肩颈点间横量', '判断领口宽窄', 'top'),
  GarmentMeasurement(
      'frontNeckDepth', '前领深', '两肩颈点连线垂直量到前领最低点', '判断露出锁骨或胸口的程度', 'top'),
  GarmentMeasurement(
      'hip', '臀围', '臀部最宽处横量，平铺宽乘 2，记录距腰头距离', '判断臀部、口袋及坐下余量', 'pants'),
  GarmentMeasurement(
      'frontRise', '前裆长', '前腰头上缘沿前裆缝量到裆底交叉点', '判断前腰落点及坐下是否顶裆', 'pants'),
  GarmentMeasurement(
      'backRise', '后裆长', '后腰头上缘沿后裆缝量到裆底交叉点', '判断后腰覆盖及下蹲是否下掉', 'pants'),
  GarmentMeasurement(
      'thigh', '大腿围', '裆底下方约 2–3 cm 横量单条裤腿，平铺宽乘 2', '判断坐下、上楼和蹲下是否受限', 'pants'),
  GarmentMeasurement(
      'outseam', '裤长／外长', '沿裤腿外侧从腰头上缘量到裤脚', '判断整条裤子的落点', 'pants'),
  GarmentMeasurement(
      'inseam', '内长', '沿裤腿内侧从裆底交叉点量到裤脚', '比较不同腰高裤子的裤腿长度', 'pants'),
  GarmentMeasurement(
      'knee', '膝围', '膝部横量单条裤腿，平铺宽乘 2，记录距裆底距离', '判断弯膝松紧及收窄位置', 'pants'),
  GarmentMeasurement(
      'calf', '小腿围', '对应小腿最粗处横量，平铺宽乘 2，记录距裤脚距离', '判断绷紧及裤腿堆积', 'pants'),
  GarmentMeasurement(
      'legOpening', '脚口围', '裤脚开口横量单条裤腿，平铺宽乘 2', '判断穿过、贴踝及盖鞋面情况', 'pants'),
  GarmentMeasurement(
      'waistPosition', '收腰测量位置（距肩颈点）', '记录上衣收腰横量处距肩颈点的垂直距离', '便于同位置比较', 'top'),
  GarmentMeasurement(
      'backWidthPosition', '背宽测量高度（距后领中心）', '记录背宽横量线距后领中心的垂直距离', '便于复测', 'top'),
  GarmentMeasurement(
      'hipPosition', '臀围位置（距腰头）', '记录臀围横量线距腰头上缘的距离', '便于复测', 'pants'),
  GarmentMeasurement(
      'kneePosition', '膝围位置（距裆底）', '记录膝围横量线距裆底距离', '比较收窄位置', 'pants'),
  GarmentMeasurement(
      'calfPosition', '小腿围位置（距裤脚）', '记录小腿围横量线距裤脚距离', '便于复测', 'pants'),
];
