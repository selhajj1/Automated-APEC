import smtplib
import sys

def send_email(receiver_email, message):
    sender_email = "your_email@outlook.com"
    password = "your_password"

    server = smtplib.SMTP('smtp-mail.outlook.com', 587)
    server.starttls()
    server.login(sender_email, password)
    server.sendmail(sender_email, receiver_email, message)
    server.quit()

if len(sys.argv) < 4:
    print("Usage: python send_email.py receiver_email 'Subject' 'Message'")
    sys.exit(1)

receiver_email = sys.argv[1]
subject = sys.argv[2]
body = sys.argv[3]

message = f"Subject: {subject}\n\n{body}"

send_email(receiver_email, message)