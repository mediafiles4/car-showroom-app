-- Car Showroom Management System - Database Schema
-- Execute this SQL in Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==================== USERS TABLE ====================
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL CHECK (role IN ('admin', 'investor')),
  full_name VARCHAR(255),
  phone VARCHAR(20),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==================== CARS TABLE ====================
CREATE TABLE cars (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  make VARCHAR(100) NOT NULL,
  model VARCHAR(100) NOT NULL,
  year INTEGER NOT NULL,
  vin VARCHAR(50) UNIQUE,
  purchase_price DECIMAL(12, 2) NOT NULL,
  purchase_date DATE NOT NULL,
  status VARCHAR(50) DEFAULT 'in_inventory' CHECK (status IN ('in_inventory', 'sold', 'maintenance')),
  condition_notes TEXT,
  photos_url TEXT[],
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==================== CAR EXPENSES TABLE ====================
CREATE TABLE car_expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  car_id UUID NOT NULL REFERENCES cars(id) ON DELETE CASCADE,
  expense_type VARCHAR(100) NOT NULL,
  amount DECIMAL(12, 2) NOT NULL,
  expense_date DATE NOT NULL,
  description TEXT,
  receipt_url TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==================== SALES TABLE ====================
CREATE TABLE sales (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  car_id UUID NOT NULL REFERENCES cars(id) ON DELETE CASCADE,
  selling_price DECIMAL(12, 2) NOT NULL,
  sale_date DATE NOT NULL,
  customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
  profit DECIMAL(12, 2) GENERATED ALWAYS AS (
    selling_price - (
      SELECT COALESCE(SUM(amount), 0) 
      FROM car_expenses 
      WHERE car_expenses.car_id = sales.car_id
    ) - (
      SELECT purchase_price 
      FROM cars 
      WHERE cars.id = sales.car_id
    )
  ) STORED,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==================== INVESTORS TABLE ====================
CREATE TABLE investors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  full_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  phone VARCHAR(20),
  address TEXT,
  total_investment DECIMAL(15, 2) DEFAULT 0,
  total_return DECIMAL(15, 2) DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==================== INVESTOR SHARES TABLE ====================
CREATE TABLE investor_shares (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  investor_id UUID NOT NULL REFERENCES investors(id) ON DELETE CASCADE,
  car_id UUID NOT NULL REFERENCES cars(id) ON DELETE CASCADE,
  share_percentage DECIMAL(5, 2) NOT NULL CHECK (share_percentage > 0 AND share_percentage <= 100),
  investment_amount DECIMAL(12, 2) NOT NULL,
  return_amount DECIMAL(12, 2) DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(investor_id, car_id)
);

-- ==================== CUSTOMERS TABLE ====================
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  full_name VARCHAR(255) NOT NULL,
  email VARCHAR(255),
  phone VARCHAR(20),
  id_document_type VARCHAR(50),
  id_document_number VARCHAR(100),
  address TEXT,
  city VARCHAR(100),
  state VARCHAR(50),
  zip_code VARCHAR(20),
  purchase_date DATE,
  purchase_amount DECIMAL(12, 2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==================== STAFF TABLE ====================
CREATE TABLE staff (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  full_name VARCHAR(255) NOT NULL,
  email VARCHAR(255),
  phone VARCHAR(20),
  position VARCHAR(100) NOT NULL,
  salary DECIMAL(12, 2) NOT NULL,
  hire_date DATE NOT NULL,
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==================== MONTHLY SALARIES TABLE ====================
CREATE TABLE monthly_salaries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  salary_amount DECIMAL(12, 2) NOT NULL,
  payment_date DATE NOT NULL,
  month_year DATE NOT NULL,
  status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'paid')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==================== OPERATING EXPENSES TABLE ====================
CREATE TABLE operating_expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  expense_type VARCHAR(100) NOT NULL,
  amount DECIMAL(12, 2) NOT NULL,
  expense_date DATE NOT NULL,
  description TEXT,
  receipt_url TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==================== DOCUMENTS TABLE ====================
CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  document_type VARCHAR(100) NOT NULL,
  file_name VARCHAR(255) NOT NULL,
  file_url TEXT NOT NULL,
  associated_entity_type VARCHAR(100),
  associated_entity_id UUID,
  upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  uploaded_by UUID REFERENCES users(id) ON DELETE SET NULL
);

-- ==================== MONTHLY REPORTS TABLE ====================
CREATE TABLE monthly_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  report_month DATE NOT NULL UNIQUE,
  total_revenue DECIMAL(15, 2),
  total_car_expenses DECIMAL(15, 2),
  total_salaries DECIMAL(15, 2),
  total_operating_expenses DECIMAL(15, 2),
  total_profit DECIMAL(15, 2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==================== INDEXES ====================
CREATE INDEX idx_cars_status ON cars(status);
CREATE INDEX idx_cars_purchase_date ON cars(purchase_date);
CREATE INDEX idx_sales_sale_date ON sales(sale_date);
CREATE INDEX idx_sales_car_id ON sales(car_id);
CREATE INDEX idx_car_expenses_car_id ON car_expenses(car_id);
CREATE INDEX idx_car_expenses_date ON car_expenses(expense_date);
CREATE INDEX idx_investor_shares_car_id ON investor_shares(car_id);
CREATE INDEX idx_investor_shares_investor_id ON investor_shares(investor_id);
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_monthly_salaries_month ON monthly_salaries(month_year);
CREATE INDEX idx_operating_expenses_date ON operating_expenses(expense_date);
CREATE INDEX idx_documents_entity ON documents(associated_entity_type, associated_entity_id);

-- ==================== TRIGGERS ====================
-- Update timestamp on users table
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cars_updated_at BEFORE UPDATE ON cars
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_investors_updated_at BEFORE UPDATE ON investors
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_staff_updated_at BEFORE UPDATE ON staff
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_monthly_reports_updated_at BEFORE UPDATE ON monthly_reports
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
