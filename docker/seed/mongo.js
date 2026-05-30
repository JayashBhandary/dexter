// Seed for Dexter MongoDB testing.

const target = db.getSiblingDB('dexter');

target.customers.drop();
target.orders.drop();

target.customers.insertMany([
  { _id: 'cust_alice', email: 'alice@example.com', full_name: 'Alice Liddell',  city: 'Bengaluru', loyalty_tier: 'gold' },
  { _id: 'cust_bob',   email: 'bob@example.com',   full_name: 'Bob Roberts',    city: 'Mumbai',    loyalty_tier: 'silver' },
  { _id: 'cust_carol', email: 'carol@example.com', full_name: 'Carol Danvers',  city: 'Delhi',     loyalty_tier: 'bronze' },
]);

const statuses = ['placed', 'shipped', 'delivered', 'returned'];
const cities   = ['Bengaluru', 'Mumbai', 'Delhi', 'Chennai'];
const seedOrders = [];
for (let i = 0; i < 50; i++) {
  seedOrders.push({
    customer_id: ['cust_alice','cust_bob','cust_carol'][i % 3],
    total_cents: Math.floor(Math.random() * 100000),
    status: statuses[i % statuses.length],
    placed_at: new Date(Date.now() - i * 86400000),
    shipping: {
      city: cities[i % cities.length],
      cod: i % 7 === 0,
    },
    items: Array.from({ length: 1 + (i % 4) }, (_, k) => ({
      sku: 'SKU-' + (1000 + i + k),
      qty: 1 + (k % 3),
      unit_cents: 500 + ((i + k) % 50) * 100,
    })),
  });
}
target.orders.insertMany(seedOrders);

print('Seeded ' + target.customers.countDocuments() + ' customers and ' +
      target.orders.countDocuments() + ' orders into "dexter" db.');
