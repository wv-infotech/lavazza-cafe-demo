# Lavazza Cafe Management Demo

A starter demo for a small cafe using Flutter Web + Node.js/Express + PostgreSQL.
All seed data is illustrative. Bakery prices and recipe quantities must be confirmed with the cafe owner.
Payments are simulated; do not use this as a production POS.

## Fastest path

### 1. Requirements
- Flutter SDK
- Node.js 20+
- PostgreSQL 15+
- Git (optional)

### 2. Start PostgreSQL
Create a database named `cafe_demo`, then run:

```bash
psql -U postgres -d cafe_demo -f backend/schema.sql
psql -U postgres -d cafe_demo -f backend/seed.sql
```

### 3. Start backend
```bash
cd backend
copy .env.example .env
npm install
npm run dev
```
On macOS/Linux use `cp .env.example .env`.
Edit `.env` to match your PostgreSQL username/password.
Backend defaults to `http://localhost:4000`.

### 4. Start Flutter Web
In a second terminal:
```bash
cd frontend
flutter pub get
flutter run -d chrome --web-port 5000
```

If you want to build web files:
```bash
flutter build web
```

## Demo workflow
1. Dashboard shows sales, order count, low stock and outstanding supplier invoices.
2. POS lets you add items and simulate a payment.
3. Completing a sale stores the sale and payment, and deducts a configured illustrative recipe quantity for tracked ingredients.
4. Purchases can be received into inventory.
5. Supplier invoices and payments are recorded separately.

## Notes
- Default product prices are based on the supplied menu where known.
- Croissant price ₹65 is an editable demonstration placeholder, not a confirmed menu price.
- Sample recipe quantities are illustrative only.
- GST is not calculated here. Menu prices are shown as GST-inclusive per the supplied menu, but production tax rules must be verified.
- This starter uses a simple demo payment flow, not a payment gateway.
- Before production: authentication/roles, transactional consistency review, idempotency, refund/return flows, tax validation, backups, audit controls, deployment secrets, and hardware testing are required.
