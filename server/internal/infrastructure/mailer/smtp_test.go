package mailer

import (
	"ai-closet-server/internal/config"
	"testing"
)

func TestRejectHeaderInjection(t *testing.T) {
	sender := New(config.Config{FromEmail: "sender@example.com"})
	for _, tc := range []struct{ to, subject string }{
		{"recipient@example.com\r\nBcc: other@example.com", "test"},
		{"recipient@example.com", "test\r\nBcc: other@example.com"},
	} {
		if err := sender.Send(tc.to, tc.subject, "body"); err == nil || err.Error() != "invalid mail header" {
			t.Fatalf("expected header rejection, got %v", err)
		}
	}
}

func TestRejectIncompleteConfiguration(t *testing.T) {
	if err := New(config.Config{}).Check(); err == nil {
		t.Fatal("expected missing configuration error")
	}
}

func TestRejectUnencryptedPort(t *testing.T) {
	cfg := config.Config{SMTPServer: "smtp.example.com", SMTPPort: 25, SMTPUsername: "user", SMTPPassword: "password", FromEmail: "sender@example.com"}
	if err := New(cfg).Check(); err == nil {
		t.Fatal("expected insecure port rejection")
	}
}
