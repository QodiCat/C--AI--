package main

import (
	"ai-closet-server/internal/config"
	"ai-closet-server/internal/infrastructure/mailer"
	"flag"
	"log"
)

func main() {
	to := flag.String("to", "", "send a test email to this recipient; omitted checks authentication only")
	flag.Parse()
	if err := config.LoadEnv(); err != nil {
		log.Fatal(err)
	}
	sender := mailer.New(config.Read())
	var err error
	if *to == "" {
		err = sender.Check()
	} else {
		err = sender.Send(*to, "AI衣橱 SMTP 测试", "这是一封 AI衣橱邮件配置测试邮件。")
	}
	if err != nil {
		log.Fatal(err)
	}
	if *to == "" {
		log.Print("SMTP TLS and authentication verified")
	} else {
		log.Print("Test email accepted by SMTP server")
	}
}
