-- Non-destructive schema reconciliation for installations where only some of
-- the earlier migrations completed. Existing application data is preserved.

begin;

create table if not exists public.factory_settings (
  key text primary key,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.factory_state (
  id text primary key,
  cash_in_hand numeric(18,2) not null default 0,
  cash_in_hand_usd numeric(18,2) not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.suppliers (
  id text primary key,
  name text not null,
  phone text,
  address text,
  total_purchased_amount numeric(18,2) not null default 0,
  total_purchased_amount_usd numeric(18,2) not null default 0,
  total_paid numeric(18,2) not null default 0,
  total_paid_usd numeric(18,2) not null default 0,
  goods_settled_amount numeric(18,2) not null default 0,
  goods_settled_amount_usd numeric(18,2) not null default 0,
  balance_owed numeric(18,2) not null default 0,
  balance_owed_usd numeric(18,2) not null default 0,
  receivable_balance numeric(18,2) not null default 0,
  receivable_balance_usd numeric(18,2) not null default 0,
  created_at date not null default current_date
);

create table if not exists public.customers (
  id text primary key,
  name text not null,
  phone text,
  address text,
  total_purchased_amount numeric(18,2) not null default 0,
  total_purchased_amount_usd numeric(18,2) not null default 0,
  total_paid numeric(18,2) not null default 0,
  total_paid_usd numeric(18,2) not null default 0,
  raw_settled_amount numeric(18,2) not null default 0,
  raw_settled_amount_usd numeric(18,2) not null default 0,
  balance_owed numeric(18,2) not null default 0,
  balance_owed_usd numeric(18,2) not null default 0,
  credit_balance numeric(18,2) not null default 0,
  credit_balance_usd numeric(18,2) not null default 0,
  created_at date not null default current_date
);

create table if not exists public.formulas (
  id text primary key,
  name text not null,
  description text,
  ingredients jsonb not null default '[]'::jsonb,
  date_created date not null default current_date
);

create table if not exists public.raw_materials (
  id text primary key,
  name text not null,
  category text not null,
  stock_kg numeric(18,3) not null default 0,
  unit_price numeric(18,2) not null default 0,
  currency text not null default 'AFN',
  supplier_id text references public.suppliers(id) on update cascade on delete set null,
  supplier_name text,
  customer_id text,
  date_added date not null default current_date,
  notes text,
  low_stock_threshold numeric(18,3) not null default 5000
);

create table if not exists public.processed_stock (
  id text primary key,
  name text not null,
  formula_id text references public.formulas(id) on update cascade on delete set null,
  stock_kg numeric(18,3) not null default 0,
  average_cost_per_kg numeric(18,4) not null default 0,
  average_cost_per_kg_usd numeric(18,4) not null default 0,
  currency text not null default 'AFN',
  last_updated date not null default current_date
);

create table if not exists public.supplier_transactions (
  id text primary key,
  supplier_id text not null references public.suppliers(id) on update cascade on delete cascade,
  raw_material_id text,
  item_name text,
  quantity_kg numeric(18,3),
  unit_price numeric(18,2),
  account_balance_after numeric(18,2),
  receivable_after numeric(18,2) not null default 0,
  date date not null default current_date,
  type text not null,
  description text not null,
  amount numeric(18,2) not null default 0,
  paid_amount numeric(18,2) not null default 0,
  remaining_amount numeric(18,2) not null default 0,
  currency text not null default 'AFN'
);

create table if not exists public.customer_transactions (
  id text primary key,
  customer_id text not null references public.customers(id) on update cascade on delete cascade,
  item_name text,
  quantity_kg numeric(18,3),
  unit_price numeric(18,2),
  account_balance_after numeric(18,2),
  date date not null default current_date,
  type text not null,
  description text not null,
  amount numeric(18,2) not null default 0,
  paid_amount numeric(18,2) not null default 0,
  remaining_amount numeric(18,2) not null default 0,
  currency text not null default 'AFN'
);

create table if not exists public.production_batches (
  id text primary key,
  date date not null default current_date,
  formula_id text references public.formulas(id) on update cascade on delete set null,
  formula_name text not null,
  total_weight_kg numeric(18,3) not null,
  cost_per_kg numeric(18,4) not null default 0,
  cost_per_kg_usd numeric(18,4) not null default 0,
  total_cost numeric(18,2) not null default 0,
  total_cost_usd numeric(18,2) not null default 0,
  operator_name text,
  notes text,
  currency text not null default 'AFN'
);

create table if not exists public.sales (
  id text primary key,
  date date not null default current_date,
  product_id text references public.processed_stock(id) on update cascade on delete set null,
  product_name text not null,
  customer_id text references public.customers(id) on update cascade on delete set null,
  supplier_id text references public.suppliers(id) on update cascade on delete set null,
  customer_name text not null,
  customer_phone text,
  unit_type text not null,
  unit_quantity numeric(18,3) not null,
  quantity_kg numeric(18,3) not null,
  sale_price_per_unit numeric(18,2) not null,
  total_amount numeric(18,2) not null,
  paid_amount numeric(18,2) not null default 0,
  remaining_amount numeric(18,2) not null default 0,
  total_cost_of_goods numeric(18,2) not null default 0,
  total_cost_of_goods_usd numeric(18,2) not null default 0,
  profit numeric(18,2) not null default 0,
  profit_usd numeric(18,2) not null default 0,
  notes text,
  currency text not null default 'AFN'
);

create table if not exists public.expenses (
  id text primary key,
  date date not null default current_date,
  category text not null,
  amount numeric(18,2) not null,
  description text not null,
  paid_by text,
  notes text,
  currency text not null default 'AFN'
);

-- Complete tables created by an older or partially executed baseline.
alter table public.factory_state
  add column if not exists cash_in_hand_usd numeric(18,2) not null default 0;

alter table public.suppliers
  add column if not exists total_purchased_amount_usd numeric(18,2) not null default 0,
  add column if not exists total_paid_usd numeric(18,2) not null default 0,
  add column if not exists goods_settled_amount numeric(18,2) not null default 0,
  add column if not exists goods_settled_amount_usd numeric(18,2) not null default 0,
  add column if not exists balance_owed_usd numeric(18,2) not null default 0,
  add column if not exists receivable_balance numeric(18,2) not null default 0,
  add column if not exists receivable_balance_usd numeric(18,2) not null default 0;

alter table public.customers
  add column if not exists total_purchased_amount_usd numeric(18,2) not null default 0,
  add column if not exists total_paid_usd numeric(18,2) not null default 0,
  add column if not exists raw_settled_amount numeric(18,2) not null default 0,
  add column if not exists raw_settled_amount_usd numeric(18,2) not null default 0,
  add column if not exists balance_owed_usd numeric(18,2) not null default 0,
  add column if not exists credit_balance numeric(18,2) not null default 0,
  add column if not exists credit_balance_usd numeric(18,2) not null default 0;

alter table public.raw_materials
  add column if not exists currency text not null default 'AFN',
  add column if not exists customer_id text;

alter table public.processed_stock
  add column if not exists average_cost_per_kg_usd numeric(18,4) not null default 0,
  add column if not exists currency text not null default 'AFN';

alter table public.supplier_transactions
  add column if not exists raw_material_id text,
  add column if not exists item_name text,
  add column if not exists quantity_kg numeric(18,3),
  add column if not exists unit_price numeric(18,2),
  add column if not exists account_balance_after numeric(18,2),
  add column if not exists receivable_after numeric(18,2) not null default 0,
  add column if not exists currency text not null default 'AFN';

alter table public.customer_transactions
  add column if not exists item_name text,
  add column if not exists quantity_kg numeric(18,3),
  add column if not exists unit_price numeric(18,2),
  add column if not exists account_balance_after numeric(18,2),
  add column if not exists currency text not null default 'AFN';

alter table public.production_batches
  add column if not exists cost_per_kg_usd numeric(18,4) not null default 0,
  add column if not exists total_cost_usd numeric(18,2) not null default 0,
  add column if not exists currency text not null default 'AFN';

alter table public.sales
  add column if not exists supplier_id text,
  add column if not exists total_cost_of_goods_usd numeric(18,2) not null default 0,
  add column if not exists profit_usd numeric(18,2) not null default 0,
  add column if not exists currency text not null default 'AFN';

alter table public.expenses
  add column if not exists currency text not null default 'AFN';

-- Replace the transaction checks with their current accepted values. NOT VALID
-- preserves legacy rows while still validating all new and changed rows.
alter table public.supplier_transactions
  drop constraint if exists supplier_transactions_type_check;
alter table public.supplier_transactions
  add constraint supplier_transactions_type_check
  check (type in ('purchase', 'payment', 'goods_settlement', 'customer_raw_settlement')) not valid;

alter table public.customer_transactions
  drop constraint if exists customer_transactions_type_check;
alter table public.customer_transactions
  add constraint customer_transactions_type_check
  check (type in ('sale', 'payment', 'raw_goods_settlement')) not valid;

create index if not exists raw_materials_supplier_id_idx on public.raw_materials(supplier_id);
create index if not exists raw_materials_customer_id_idx on public.raw_materials(customer_id);
create index if not exists processed_stock_formula_id_idx on public.processed_stock(formula_id);
create index if not exists supplier_transactions_supplier_id_date_idx on public.supplier_transactions(supplier_id, date desc);
create index if not exists supplier_transactions_raw_material_id_idx on public.supplier_transactions(raw_material_id);
create index if not exists customer_transactions_customer_id_date_idx on public.customer_transactions(customer_id, date desc);
create index if not exists production_batches_date_idx on public.production_batches(date desc);
create index if not exists sales_date_idx on public.sales(date desc);
create index if not exists sales_customer_id_idx on public.sales(customer_id);
create index if not exists sales_supplier_id_idx on public.sales(supplier_id);
create index if not exists expenses_date_idx on public.expenses(date desc);

insert into public.factory_state (id, cash_in_hand, cash_in_hand_usd)
values ('default', 0, 0)
on conflict (id) do nothing;

insert into public.factory_settings (key, data)
values ('inventory', jsonb_build_object('lowStockThreshold', 5000))
on conflict (key) do nothing;

-- Restore consistent access rules even if policy creation was where an older
-- migration stopped. The app deliberately exposes these rows only to signed-in
-- Supabase users.
do $policies$
declare
  table_name text;
begin
  foreach table_name in array array[
    'factory_settings', 'factory_state', 'suppliers', 'customers', 'formulas',
    'raw_materials', 'processed_stock', 'supplier_transactions',
    'customer_transactions', 'production_batches', 'sales', 'expenses'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('drop policy if exists "Authenticated users have full access" on public.%I', table_name);
    execute format(
      'create policy "Authenticated users have full access" on public.%I for all to authenticated using (true) with check (true)',
      table_name
    );
    execute format('grant select, insert, update, delete on public.%I to authenticated', table_name);
    execute format('revoke all on public.%I from anon', table_name);
  end loop;
end
$policies$;

commit;
