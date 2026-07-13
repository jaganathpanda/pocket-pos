INSERT INTO roles(name) VALUES
('super_admin'),
('shop_owner'),
('shop_manager'),
('cashier');

INSERT INTO users(username, password_hash, pin_hash, role_id, is_active) VALUES
('admin', 'admin123', '1234', 1, 1),
('owner', 'owner123', '1234', 2, 1),
('cashier1', 'cashier123', '1111', 4, 1);

INSERT INTO shops(name, gst_number, mobile, email, address, invoice_prefix, currency, tax_mode)
VALUES ('Pocket Kirana', '29ABCDE1234F1Z5', '9876543210', 'owner@pocketpos.local', 'Main Road, Bengaluru', 'INV', 'INR', 'exclusive');

INSERT INTO categories(name) VALUES
('Food'),
('Dal'),
('Rice'),
('Flour'),
('Books'),
('Stationery'),
('Bakery');

INSERT INTO products(name, product_code, sku, barcode, category_id, brand, purchase_price, selling_price, mrp, tax_percent, unit, is_active)
VALUES
('Toor Dal 1kg', 'P001', 'DAL-1KG', '8901234567001', 2, 'Local', 95, 110, 120, 5, 'kg', 1),
('Rice 5kg', 'P002', 'RICE-5KG', '8901234567002', 3, 'Premium', 240, 275, 299, 5, 'kg', 1),
('Notebook A5', 'P003', 'NB-A5', '8901234567003', 6, 'Classmate', 28, 35, 40, 12, 'piece', 1),
('Bread Small', 'P004', 'BR-SM', '8901234567004', 7, 'Bakery Fresh', 20, 28, 30, 0, 'piece', 1);

INSERT INTO inventory(product_id, variant_id, current_stock, available_stock, low_stock_threshold)
VALUES
(1, NULL, 120, 120, 20),
(2, NULL, 80, 80, 15),
(3, NULL, 220, 220, 30),
(4, NULL, 40, 40, 10);

INSERT INTO carts(name, status) VALUES ('Walk-in 1', 'active');
