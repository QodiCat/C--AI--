package auth

import (
	"crypto/sha256"
	"errors"
	"regexp"
	"testing"
	"time"
)

type fakeMail struct {
	body string
	err  error
}

func (f *fakeMail) Send(to, subject, body string) error { f.body = body; return f.err }
func TestVerificationLifecycle(t *testing.T) {
	m := &fakeMail{}
	v := NewVerifier(m)
	if err := v.Send("test@example.com", "ip"); err != nil {
		t.Fatal(err)
	}
	if err := v.Send("test@example.com", "ip"); !errors.Is(err, ErrRateLimit) {
		t.Fatal("missing resend limit")
	}
	code := regexp.MustCompile(`[0-9]{6}`).FindString(m.body)
	if err := v.Register("other@example.com", code, func() error { return nil }); !errors.Is(err, ErrCode) {
		t.Fatal("wrong email accepted")
	}
	if err := v.Register("test@example.com", "wrong", func() error { t.Fatal("invalid code created account"); return nil }); !errors.Is(err, ErrCode) {
		t.Fatal(err)
	}
	if err := v.Register("test@example.com", code, func() error { return nil }); err != nil {
		t.Fatal(err)
	}
	if err := v.Register("test@example.com", code, func() error { return nil }); !errors.Is(err, ErrCode) {
		t.Fatal("code reused")
	}
}
func TestExpiredAndLockedCodes(t *testing.T) {
	for _, expired := range []bool{true, false} {
		v := NewVerifier(&fakeMail{})
		expires := time.Now().Add(time.Minute)
		attempts := 5
		if expired {
			expires = time.Now().Add(-time.Minute)
			attempts = 0
		}
		v.codes["test@example.com"] = verification{hash: sha256.Sum256([]byte("123456")), expires: expires, attempts: attempts}
		if err := v.Register("test@example.com", "123456", func() error { return nil }); !errors.Is(err, ErrCode) {
			t.Fatal("invalid code accepted")
		}
	}
}
func TestFailedDeliveryAndIPQuota(t *testing.T) {
	m := &fakeMail{err: errors.New("delivery failed")}
	v := NewVerifier(m)
	for i := 0; i < 10; i++ {
		if err := v.Send("test@example.com", "ip"); err == nil {
			t.Fatal("failure ignored")
		}
	}
	if len(v.codes) != 0 {
		t.Fatal("failed mail stored code")
	}
	if err := v.Send("test@example.com", "ip"); !errors.Is(err, ErrRateLimit) {
		t.Fatal("missing IP limit")
	}
}
