import imaplib
import email

EMAIL = "pantri.verify@gmail.com"
APP_PASSWORD = "etbdbrzprcsyeigy"

# Connect
mail = imaplib.IMAP4_SSL("imap.gmail.com")
mail.login(EMAIL, APP_PASSWORD)

# Select inbox
mail.select("inbox")

# Search for unread emails
status, messages = mail.search(None, 'UNSEEN')

email_ids = messages[0].split()

for e_id in email_ids:
    status, msg_data = mail.fetch(e_id, "(RFC822)")
    raw_email = msg_data[0][1]
    msg = email.message_from_bytes(raw_email)

    subject = msg["subject"]
    sender = msg["from"]

    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_type() == "text/plain":
                body = part.get_payload(decode=True).decode()
                print("Email body:", body)
    else:
        body = msg.get_payload(decode=True).decode()
        print("Email body:", body)

    # Mark as read
    mail.store(e_id, '+FLAGS', '\\Seen')

mail.logout()