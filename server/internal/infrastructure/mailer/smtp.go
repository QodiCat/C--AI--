package mailer

import (
	"crypto/tls"
	"fmt"
	"mime"
	"net"
	"net/mail"
	"net/smtp"
	"strconv"
	"strings"
	"time"

	"ai-closet-server/internal/config"
)

type Sender struct{ cfg config.Config }

func New(cfg config.Config) *Sender { return &Sender{cfg: cfg} }

func (s *Sender) connect() (*smtp.Client, error) {
	c := s.cfg
	if c.SMTPServer == "" || c.SMTPUsername == "" || c.SMTPPassword == "" || c.FromEmail == "" {
		return nil, fmt.Errorf("SMTP configuration incomplete")
	}
	if c.SMTPPort != 465 {
		return nil, fmt.Errorf("SMTP requires implicit TLS on port 465")
	}
	if _, err := mail.ParseAddress(c.FromEmail); err != nil {
		return nil, fmt.Errorf("invalid FROM_EMAIL")
	}
	conn, err := tls.DialWithDialer(&net.Dialer{Timeout: 15 * time.Second}, "tcp", net.JoinHostPort(c.SMTPServer, strconv.Itoa(c.SMTPPort)), &tls.Config{ServerName: c.SMTPServer, MinVersion: tls.VersionTLS12})
	if err != nil {
		return nil, fmt.Errorf("SMTP TLS connection: %w", err)
	}
	if err := conn.SetDeadline(time.Now().Add(30 * time.Second)); err != nil {
		conn.Close()
		return nil, err
	}
	client, err := smtp.NewClient(conn, c.SMTPServer)
	if err != nil {
		conn.Close()
		return nil, err
	}
	if err := client.Auth(smtp.PlainAuth("", c.SMTPUsername, c.SMTPPassword, c.SMTPServer)); err != nil {
		client.Close()
		return nil, fmt.Errorf("SMTP authentication: %w", err)
	}
	return client, nil
}

// Check verifies TLS and authentication without sending a message.
func (s *Sender) Check() error {
	client, err := s.connect()
	if err != nil {
		return err
	}
	defer client.Close()
	return client.Quit()
}

func (s *Sender) Send(to, subject, body string) error {
	if strings.ContainsAny(to+subject+s.cfg.FromEmail, "\r\n") {
		return fmt.Errorf("invalid mail header")
	}
	recipient, err := mail.ParseAddress(to)
	if err != nil {
		return fmt.Errorf("invalid recipient")
	}
	from, err := mail.ParseAddress(s.cfg.FromEmail)
	if err != nil {
		return fmt.Errorf("invalid FROM_EMAIL")
	}
	client, err := s.connect()
	if err != nil {
		return err
	}
	defer client.Close()
	if err = client.Mail(from.Address); err != nil {
		return err
	}
	if err = client.Rcpt(recipient.Address); err != nil {
		return err
	}
	writer, err := client.Data()
	if err != nil {
		return err
	}
	message := "From: " + from.String() + "\r\nTo: " + recipient.String() + "\r\nSubject: " + mime.QEncoding.Encode("UTF-8", subject) + "\r\nDate: " + time.Now().Format(time.RFC1123Z) + "\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\nContent-Transfer-Encoding: 8bit\r\n\r\n" + strings.ReplaceAll(strings.ReplaceAll(body, "\r\n", "\n"), "\n", "\r\n") + "\r\n"
	if _, err = writer.Write([]byte(message)); err != nil {
		writer.Close()
		return err
	}
	if err = writer.Close(); err != nil {
		return err
	}
	return client.Quit()
}
