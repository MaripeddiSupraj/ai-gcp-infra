# GoDaddy DNS Setup Instructions

## For Client

### Step 1: Go to GoDaddy DNS Management

1. Visit: https://dcc.godaddy.com/manage/dns
2. Log in to your GoDaddy account
3. Select the domain you want to use

### Step 2: Add Wildcard DNS Record

Click the **"Add"** button and enter:

```
Type: A
Host: *.ai
Points to: <IP ADDRESS WE PROVIDE>
TTL: 600 seconds (or 1 Hour)
```

**Visual Guide:**

```
┌─────────────────────────────────────────┐
│ Type: [A ▼]                             │
│                                         │
│ Host: [*.ai                          ]  │
│                                         │
│ Points to: [34.123.45.67            ]  │
│                                         │
│ TTL: [600 seconds ▼]                    │
│                                         │
│         [Cancel]  [Save]                │
└─────────────────────────────────────────┘
```

### Step 3: Save and Wait

- Click **"Save"**
- Wait 5-10 minutes for DNS propagation
- You'll receive confirmation when it's ready

---

## Example

If your domain is `mycompany.com` and you choose subdomain `ai`:

**DNS Record:**
```
Type: A
Host: *.ai
Points to: 34.123.45.67
TTL: 600
```

**Result:**
- `vs-code-abc123.ai.mycompany.com` ✅
- `vs-code-xyz789.ai.mycompany.com` ✅
- Any `*.ai.mycompany.com` ✅

---

## Common Subdomains

Choose one:
- `*.ai` → `ai.mycompany.com`
- `*.workspace` → `workspace.mycompany.com`
- `*.vscode` → `vscode.mycompany.com`
- `*.dev` → `dev.mycompany.com`
- `*.app` → `app.mycompany.com`

---

## Verification

After adding the record, test it:

1. Go to: https://dnschecker.org
2. Enter: `vs-code-test.ai.mycompany.com`
3. Should show the IP address we provided

Or use command line:
```bash
nslookup vs-code-test.ai.mycompany.com
```

---

## Troubleshooting

**Q: I don't see the "Add" button**
A: Make sure you're in the DNS Management section, not Domain Settings

**Q: What if I already have an A record for *.ai?**
A: Delete the old one first, then add the new one

**Q: How long does DNS take to work?**
A: Usually 5-10 minutes, maximum 1 hour

**Q: Can I use the root domain instead?**
A: Yes, but we recommend a subdomain for better organization

---

## Screenshot Reference

![GoDaddy DNS Add Record](https://i.imgur.com/example.png)

1. Click "DNS" tab
2. Scroll to "Records" section
3. Click "Add" button
4. Fill in the form as shown above
5. Click "Save"

---

## Need Help?

Contact us if you have any issues with the DNS setup.
