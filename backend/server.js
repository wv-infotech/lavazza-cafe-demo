require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const app = express();
app.use(cors());
app.use(express.json());
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const port = process.env.PORT || 4000;
const jwtSecret = process.env.JWT_SECRET;
if (!jwtSecret) {
  console.error('Missing JWT_SECRET in backend/.env. Add a long random secret before starting.');
  process.exit(1);
}

function authenticate(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) return res.status(401).json({ error: 'Authentication required.' });
  try {
    req.user = jwt.verify(token, jwtSecret);
    next();
  } catch (_) {
    return res.status(401).json({ error: 'Session expired or invalid. Please log in again.' });
  }
}
function requireAdmin(req, res, next) {
  if (req.user?.role !== 'admin') return res.status(403).json({ error: 'Administrator access required.' });
  next();
}

app.get('/api/health', async (_req, res) => {
  try { await pool.query('SELECT 1'); res.json({ ok: true, service: 'cafe-demo-api' }); }
  catch (e) { res.status(500).json({ ok: false, error: 'Database connection failed' }); }
});
// Public login endpoint. Passwords are verified against bcrypt hashes.
app.post('/api/auth/login', async (req, res) => {
  try {
    const email = String(req.body.email || '').trim().toLowerCase();
    const password = String(req.body.password || '');
    if (!email || !password) return res.status(400).json({ error: 'Email and password are required.' });
    const { rows } = await pool.query(
      'SELECT id, name, email, password_hash, role, active FROM app_users WHERE email=$1',
      [email]
    );
    const user = rows[0];
    if (!user || !user.active || !(await bcrypt.compare(password, user.password_hash))) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }
    const token = jwt.sign(
      { id: user.id, email: user.email, name: user.name, role: user.role },
      jwtSecret,
      { expiresIn: '8h' }
    );
    res.json({ token, user: { id: user.id, name: user.name, email: user.email, role: user.role } });
  } catch (e) {
    res.status(500).json({ error: 'Login failed. Check the database setup.' });
  }
});

// One-time first-admin setup. Works only while no admin account exists.
app.post('/api/auth/setup-admin', async (req, res) => {
  try {
    const setupKey = String(req.body.setupKey || '');
    if (!process.env.ADMIN_SETUP_KEY || setupKey !== process.env.ADMIN_SETUP_KEY) {
      return res.status(403).json({ error: 'Invalid administrator setup key.' });
    }
    const existing = await pool.query("SELECT id FROM app_users WHERE role='admin' LIMIT 1");
    if (existing.rows.length) return res.status(409).json({ error: 'An administrator already exists. Setup is closed.' });
    const name = String(req.body.name || '').trim();
    const email = String(req.body.email || '').trim().toLowerCase();
    const password = String(req.body.password || '');
    if (!name || !email.includes('@') || password.length < 12) {
      return res.status(400).json({ error: 'Enter a name, valid email, and password of at least 12 characters.' });
    }
    const hash = await bcrypt.hash(password, 12);
    const result = await pool.query(
      "INSERT INTO app_users(name,email,password_hash,role,active) VALUES($1,$2,$3,'admin',TRUE) RETURNING id,name,email,role",
      [name, email, hash]
    );
    res.status(201).json({ message: 'Administrator created. You can now log in.', user: result.rows[0] });
  } catch (e) {
    if (e.code === '23505') return res.status(409).json({ error: 'That email is already registered.' });
    res.status(500).json({ error: 'Administrator setup failed. Check that auth.sql has been applied.' });
  }
});

// Protect every business endpoint below this point.
app.use('/api', authenticate);

app.post('/api/users', requireAdmin, async (req, res) => {
  try {
    const name = String(req.body.name || '').trim();
    const email = String(req.body.email || '').trim().toLowerCase();
    const password = String(req.body.password || '');
    const role = req.body.role === 'admin' ? 'admin' : 'staff';
    if (!name || !email.includes('@') || password.length < 12) {
      return res.status(400).json({ error: 'Enter a name, valid email, and password of at least 12 characters.' });
    }
    const hash = await bcrypt.hash(password, 12);
    const { rows } = await pool.query(
      'INSERT INTO app_users(name,email,password_hash,role,active) VALUES($1,$2,$3,$4,TRUE) RETURNING id,name,email,role,active',
      [name, email, hash, role]
    );
    res.status(201).json(rows[0]);
  } catch (e) {
    if (e.code === '23505') return res.status(409).json({ error: 'That email is already registered.' });
    res.status(500).json({ error: 'Could not create user.' });
  }
});

app.get('/api/users', requireAdmin, async (_req, res) => {
  try {
    const { rows } = await pool.query('SELECT id,name,email,role,active FROM app_users ORDER BY id');
    res.json(rows);
  } catch (e) { res.status(500).json({ error: 'Could not load users.' }); }
});

app.get('/api/products', async (_req, res) => {
  try {
    const { rows } = await pool.query('SELECT id,name,category,variant,price,stock_item_id FROM products WHERE active=true ORDER BY category,name,variant');
    res.json(rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});
app.get('/api/dashboard', async (_req, res) => {
  try {
    const sales = await pool.query(`SELECT COALESCE(SUM(total),0) sales, COUNT(*) orders FROM sales WHERE status='completed' AND created_at::date=CURRENT_DATE`);
    const low = await pool.query('SELECT COUNT(*) count FROM inventory_items WHERE quantity <= reorder_level');
    const invoices = await pool.query(`SELECT COALESCE(SUM(p.quantity*p.unit_cost),0) total FROM purchases p WHERE p.invoice_status='unpaid'`);
    const inventory = await pool.query('SELECT id,name,unit,quantity,reorder_level,unit_cost FROM inventory_items ORDER BY (quantity <= reorder_level) DESC,name');
    const recent = await pool.query('SELECT id,total,payment_method,status,created_at FROM sales ORDER BY id DESC LIMIT 8');
    res.json({ sales: Number(sales.rows[0].sales), orders: Number(sales.rows[0].orders),
      lowStock: Number(low.rows[0].count), unpaidInvoices: Number(invoices.rows[0].total),
      inventory: inventory.rows, recentSales: recent.rows });
  } catch (e) { res.status(500).json({ error: e.message }); }
});
app.post('/api/sales', async (req, res) => {
  const { items, paymentMethod } = req.body;
  if (!Array.isArray(items) || !items.length || !['Cash','UPI','Card','Split'].includes(paymentMethod)) {
    return res.status(400).json({ error: 'Valid items and payment method are required.' });
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    let total = 0;
    const validated = [];
    for (const item of items) {
      const q = Math.floor(Number(item.quantity));
      if (!Number.isInteger(q) || q < 1) throw new Error('Invalid quantity');
      const result = await client.query('SELECT id,name,variant,price FROM products WHERE id=$1 AND active=true AND price > 0', [item.productId]);
      if (!result.rows.length) throw new Error('Product not found or price not configured');
      const p = result.rows[0];
      const price = Number(p.price), lineTotal = price * q;
      total += lineTotal;
      validated.push({ ...p, quantity:q, price, lineTotal });
    }
    const sale = await client.query('INSERT INTO sales(total,payment_method) VALUES($1,$2) RETURNING *',[total,paymentMethod]);
    for (const item of validated) {
      await client.query('INSERT INTO sale_items(sale_id,product_id,product_name,quantity,unit_price,line_total) VALUES($1,$2,$3,$4,$5,$6)',
        [sale.rows[0].id,item.id,`${item.name}${item.variant ? ' ('+item.variant+')' : ''}`,item.quantity,item.price,item.lineTotal]);
      // Illustrative demo recipes: hot/cold coffee drinks use 18g beans per item; latte variants also use 200ml milk.
      const name = item.name.toLowerCase();
      if (name.includes('espresso') || name.includes('americano') || name.includes('latte') || name.includes('cappuccino') || name.includes('mocha') || name.includes('flat white')) {
        const beans = 18 * item.quantity;
        await client.query('UPDATE inventory_items SET quantity=quantity-$1 WHERE name=$2',[beans,'Arabica Coffee Beans']);
        await client.query(`INSERT INTO stock_movements(inventory_item_id,movement_type,quantity_change,note)
          SELECT id,'sale_consumption',$1,$2 FROM inventory_items WHERE name='Arabica Coffee Beans'`,[-beans,`Demo recipe for sale #${sale.rows[0].id}`]);
      }
      if (name.includes('latte') || name.includes('cappuccino') || name.includes('flat white')) {
        const milk = 200 * item.quantity;
        await client.query('UPDATE inventory_items SET quantity=quantity-$1 WHERE name=$2',[milk,'Milk']);
        await client.query(`INSERT INTO stock_movements(inventory_item_id,movement_type,quantity_change,note)
          SELECT id,'sale_consumption',$1,$2 FROM inventory_items WHERE name='Milk'`,[-milk,`Demo recipe for sale #${sale.rows[0].id}`]);
      }
      if (name === 'croissant') {
        await client.query('UPDATE inventory_items SET quantity=quantity-$1 WHERE name=$2',[item.quantity,'Croissant']);
        await client.query(`INSERT INTO stock_movements(inventory_item_id,movement_type,quantity_change,note)
          SELECT id,'sale',$1,$2 FROM inventory_items WHERE name='Croissant'`,[-item.quantity,`Sale #${sale.rows[0].id}`]);
      }
    }
    await client.query('COMMIT');
    res.status(201).json({ saleId:sale.rows[0].id, total, paymentMethod, items:validated });
  } catch (e) {
    await client.query('ROLLBACK');
    res.status(400).json({ error:e.message });
  } finally { client.release(); }
});
app.post('/api/purchases', async (req, res) => {
  const { supplierId, itemName, quantity, unit, unitCost, inventoryItemId, receiveNow } = req.body;
  const q=Number(quantity), cost=Number(unitCost);
  if (!supplierId || !itemName || !(q>0) || !(cost>=0) || !unit) return res.status(400).json({error:'Complete all purchase fields.'});
  const client=await pool.connect();
  try {
    await client.query('BEGIN');
    const p=await client.query(`INSERT INTO purchases(supplier_id,item_name,quantity,unit,unit_cost,status,invoice_status)
      VALUES($1,$2,$3,$4,$5,$6,'unpaid') RETURNING *`,
      [supplierId,itemName,q,unit,cost,receiveNow?'received':'ordered']);
    if (receiveNow && inventoryItemId) {
      await client.query('UPDATE inventory_items SET quantity=quantity+$1,unit_cost=$2 WHERE id=$3',[q,cost,inventoryItemId]);
      await client.query(`INSERT INTO stock_movements(inventory_item_id,movement_type,quantity_change,note)
        VALUES($1,'goods_receipt',$2,$3)`,[inventoryItemId,q,`Purchase #${p.rows[0].id} received`]);
    }
    await client.query('COMMIT'); res.status(201).json(p.rows[0]);
  } catch(e) { await client.query('ROLLBACK'); res.status(400).json({error:e.message}); }
  finally { client.release(); }
});
app.post('/api/purchases/:id/pay', async (req,res) => {
  const amount=Number(req.body.amount), method=req.body.paymentMethod || 'Bank';
  const client=await pool.connect();
  try {
    await client.query('BEGIN');
    const p=await client.query('SELECT * FROM purchases WHERE id=$1 FOR UPDATE',[req.params.id]);
    if (!p.rows.length) throw new Error('Purchase not found');
    const balance=Number(p.rows[0].quantity)*Number(p.rows[0].unit_cost);
    const paid=await client.query('SELECT COALESCE(SUM(amount),0) total FROM supplier_payments WHERE purchase_id=$1',[req.params.id]);
    const due=balance-Number(paid.rows[0].total);
    const toPay=amount || due;
    if (!(toPay>0) || toPay>due) throw new Error('Payment must be greater than zero and not exceed the outstanding balance.');
    await client.query('INSERT INTO supplier_payments(purchase_id,amount,payment_method) VALUES($1,$2,$3)',[req.params.id,toPay,method]);
    const newDue=due-toPay;
    await client.query('UPDATE purchases SET invoice_status=$1 WHERE id=$2',[newDue===0?'paid':'partial',req.params.id]);
    await client.query('COMMIT'); res.json({ok:true,remaining:newDue});
  } catch(e) { await client.query('ROLLBACK'); res.status(400).json({error:e.message}); }
  finally { client.release(); }
});
app.get('/api/purchases', async (_req,res) => {
  try {
    const {rows}=await pool.query(`SELECT p.*,s.name supplier_name,
      p.quantity*p.unit_cost total,
      COALESCE((SELECT SUM(sp.amount) FROM supplier_payments sp WHERE sp.purchase_id=p.id),0) paid
      FROM purchases p JOIN suppliers s ON s.id=p.supplier_id ORDER BY p.id DESC`);
    res.json(rows);
  } catch(e) {res.status(500).json({error:e.message});}
});
app.get('/api/suppliers', async (_req,res) => {
  try { const {rows}=await pool.query('SELECT * FROM suppliers ORDER BY name'); res.json(rows); }
  catch(e){res.status(500).json({error:e.message});}
});
app.listen(port, () => console.log(`Cafe demo API running on http://localhost:${port}`));
