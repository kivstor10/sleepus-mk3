# Sleepus Waitlist API

This Worker accepts `POST /api/waitlist` from `https://sleepus.dev` and stores
unique email addresses in Cloudflare D1.

## Deploy

1. Authenticate: `npx wrangler login`
2. Create the database: `npx wrangler d1 create sleepus-waitlist`
3. Copy the returned `database_id` into `wrangler.jsonc`.
4. Apply the schema: `npx wrangler d1 migrations apply sleepus-waitlist --remote`
5. Deploy: `npx wrangler deploy`
6. Set `WAITLIST_ENDPOINT` in `../landing.js` to the deployed Worker URL plus `/api/waitlist`.

Export signups with:

```powershell
npx wrangler d1 execute sleepus-waitlist --remote --command "SELECT email, created_at FROM waitlist_signups ORDER BY created_at DESC"
```

## View signups

Run `./view-signups.ps1` to print the current signups. To create a CSV file:

```powershell
./view-signups.ps1 -ExportPath ./waitlist-signups.csv
```