# Email OTP Functions (SendGrid)

## Secrets
Set these Firebase Functions secrets (never store in Flutter):

- `SENDGRID_API_KEY`
- `SENDGRID_FROM_EMAIL` (example: `no-reply@yourdomain.com`)
- `SENDGRID_FROM_NAME` (example: `eBill Wallet`)

## Deploy
1. `firebase init functions` (if not initialized yet, select Node.js)
2. `cd functions`
3. `npm install`
4. `firebase functions:secrets:set SENDGRID_API_KEY`
5. `firebase functions:secrets:set SENDGRID_FROM_EMAIL`
6. `firebase functions:secrets:set SENDGRID_FROM_NAME`
7. `cd ..`
8. `firebase deploy --only functions`

## Deliverability Checklist
- Verify sender domain in SendGrid.
- Configure SPF DNS record.
- Configure DKIM DNS records.
- Configure DMARC policy.
- Use a consistent sender (`from`) address and domain.
- Keep OTP email short and transactional.
