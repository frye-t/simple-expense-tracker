CREATE TABLE user_accounts(
  id serial PRIMARY KEY,
  first_name text NOT NULL,
  initial_balance decimal(6,2) NOT NULL
);

CREATE TABLE user_login_data(
  user_id integer PRIMARY KEY REFERENCES user_accounts(id),
  user_name text NOT NULL,
  password text NOT NULL
);

CREATE TABLE categories(
  id serial PRIMARY KEY,
  name text NOT NULL
);

CREATE TYPE transaction_type_enum AS ENUM ('withdrawal', 'deposit');

CREATE TABLE expenses(
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES user_accounts(id),
  memo text NOT NULL,
  transaction_date date NOT NULL,
  transaction_type transaction_type_enum NOT NULL,
  amount decimal(6,2) NOT NULL,
  category_id integer NOT NULL REFERENCES categories(id)
);

INSERT INTO user_accounts (first_name, initial_balance) VALUES ('tyler', 500.00);
INSERT INTO user_login_data (user_id, user_name, password)
  VALUES ('1', 'PetFrog', 'abcd1234');

INSERT INTO categories (name)
  VALUES
    ('Housing'),
    ('Transportation'),
    ('Food'),
    ('Utilities'),
    ('Insurance'),
    ('Medical'),
    ('Savings'),
    ('Investment'),
    ('Debt'),
    ('Personal'),
    ('Recreation'),
    ('Miscellaneous'),
    ('Income');

INSERT INTO expenses (user_id, memo, transaction_date, transaction_type, amount, category_id)
  VALUES 
    (1, 'Rent', NOW(), 'withdrawal', 420.69, 1),
    (1, 'Electric', NOW(), 'withdrawal', 32.74, 4),
    (1, 'Medical Insurance', NOW(), 'withdrawal', 450.00, 5),
    (1, 'Payday', NOW(), 'deposit', 1000.26, 13),
    (1, 'Savings', NOW(), 'withdrawal', 250.00, 7),
    (1, 'Med Bill', NOW(), 'withdrawal', 269.99, 9),
    (1, 'Uber', NOW(), 'withdrawal', 32.16, 2),
    (1, 'Some Income', NOW(), 'deposit', 800.00, 13),
    (1, 'WoW Sub', NOW(), 'withdrawal', 14.99, 11),
    (1, 'Clothes', NOW(), 'withdrawal', 42.87, 10),
    (1, 'Saw Doc', NOW(), 'withdrawal', 127.00, 6);
