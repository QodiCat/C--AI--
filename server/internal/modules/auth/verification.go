package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"errors"
	"fmt"
	"math/big"
	"sync"
	"time"
)

type MailSender interface {
	Send(string, string, string) error
}
type verification struct {
	hash          [32]byte
	expires, sent time.Time
	attempts      int
}
type ipQuota struct {
	start time.Time
	count int
}
type Verifier struct {
	mu     sync.Mutex
	codes  map[string]verification
	ips    map[string]ipQuota
	sender MailSender
}

var ErrRateLimit = errors.New("请稍后再发送验证码")
var ErrCode = errors.New("验证码错误或已过期，请重新获取")

func NewVerifier(sender MailSender) *Verifier {
	return &Verifier{codes: make(map[string]verification), ips: make(map[string]ipQuota), sender: sender}
}
func (v *Verifier) Send(email, ip string) error {
	return v.send(email, ip, email, "注册")
}

func (v *Verifier) SendPasswordReset(email, ip string) error {
	return v.send(email, ip, "reset:"+email, "重置密码")
}

func (v *Verifier) ResetPassword(email, code string, update func() error) error {
	return v.Register("reset:"+email, code, update)
}

func (v *Verifier) send(email, ip, key, purpose string) error {
	v.mu.Lock()
	defer v.mu.Unlock()
	now := time.Now()
	for k, c := range v.codes {
		if now.After(c.expires) {
			delete(v.codes, k)
		}
	}
	for k, q := range v.ips {
		if now.Sub(q.start) >= time.Hour {
			delete(v.ips, k)
		}
	}
	if c, ok := v.codes[key]; ok && now.Sub(c.sent) < time.Minute {
		return ErrRateLimit
	}
	q := v.ips[ip]
	if q.start.IsZero() {
		q.start = now
	}
	if q.count >= 10 || len(v.codes) >= 10000 || len(v.ips) >= 10000 {
		return ErrRateLimit
	}
	q.count++
	v.ips[ip] = q
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return err
	}
	code := fmt.Sprintf("%06d", n.Int64())
	if err := v.sender.Send(email, "AI衣橱"+purpose+"验证码", "你的"+purpose+"验证码是："+code+"\n验证码 10 分钟内有效，请勿向他人透露。"); err != nil {
		return err
	}
	v.codes[key] = verification{hash: sha256.Sum256([]byte(code)), expires: time.Now().Add(10 * time.Minute), sent: now}
	return nil
}

// Register serializes verification and account creation so a code can be used once.
func (v *Verifier) Register(email, code string, create func() error) error {
	v.mu.Lock()
	defer v.mu.Unlock()
	c, ok := v.codes[email]
	if !ok || time.Now().After(c.expires) || c.attempts >= 5 {
		delete(v.codes, email)
		return ErrCode
	}
	hash := sha256.Sum256([]byte(code))
	if len(code) != 6 || subtle.ConstantTimeCompare(hash[:], c.hash[:]) != 1 {
		c.attempts++
		v.codes[email] = c
		return ErrCode
	}
	if err := create(); err != nil {
		return err
	}
	delete(v.codes, email)
	return nil
}
