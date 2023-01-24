require 'pg'
require 'bcrypt'

require_relative 'expense'

class DatabasePersistence 
  def initialize(logger)
    @db = PG.connect("postgres://postgres:RPbpMulhQ3DDqCD@petfrog-expenses-db.internal:5432")
    #@db = PG.connect(dbname: "expenses")
    @logger = logger

    #@db.setup_schema
  end

  def query(statement, *params)
    @logger.info("#{statement}: #{params}")
    @db.exec_params(statement, params)
  end

  def setup_schema
    result = @db.exec <<~SQL
      SELECT COUNT(*) FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = 'expenses';
    SQL

    if result[0]["count"] == "0"
      @db.exec <<~SQL
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
      SQL
    end
  end

  def all_expenses(user)
    expenses_sql = <<~SQL
      SELECT expenses.id, expenses.memo,
             expenses.transaction_date AS date, expenses.transaction_type AS type,
             expenses.amount, categories.name AS category
        FROM expenses JOIN categories
          ON expenses.category_id = categories.id
        WHERE user_id = $1
        ORDER BY date, expenses.memo;
    SQL

    uid = uid_from_user_name(user)

    expense_result = query(expenses_sql, uid)

    balance_result = query("SELECT initial_balance FROM user_accounts WHERE id = uid")
    balance = balance_result[0]['initial_balance'].to_f

    expenses = expense_result.map do |tuple|
      balance = running_balance(balance, tuple['amount'].to_f, tuple['type'])
      tuple_to_expense(tuple, balance)
    end
  end

  def search(term, start_date, end_date, user)
    search_sql = <<~SQL
      SELECT expenses.id, expenses.memo,
             expenses.transaction_date AS date, expenses.transaction_type AS type,
             expenses.amount, categories.name AS category
        FROM expenses JOIN categories
          ON expenses.category_id = categories.id
        WHERE expenses.memo ILIKE $1::text
          AND expenses.transaction_date BETWEEN $2 AND $3
          AND user_id = $4
        ORDER BY date, expenses.memo;
    SQL

    uid = uid_from_user_name(user)

    expense_result = query(search_sql, "%#{term}%", start_date, end_date, uid)
    expenses = expense_result.map do |tuple|
      tuple_to_expense(tuple, nil)
    end
  end

  def add_expense(expense, user)
    uid = uid_from_user_name(user)
    cat_id = cat_id_from_name(expense.category)

    add_expense_sql = <<~SQL
      INSERT INTO expenses (user_id, memo, transaction_date, transaction_type, amount, category_id)
        VALUES ($1, $2, $3, $4, $5, $6)
    SQL
    query(add_expense_sql, uid, expense.memo, expense.date, expense.type, expense.amount, cat_id)
  end

  def delete_expense(id)
    sql = "DELETE FROM expenses WHERE id = $1"
    query(sql, id)
  end

  def single_expense(expense_id, user)
    sql = <<~SQL
      SELECT expenses.id, expenses.memo, expenses.transaction_date AS date,
             expenses.transaction_type AS type, expenses.amount, 
             categories.name AS category
        FROM expenses JOIN user_login_data
          ON expenses.user_id = user_login_data.user_id
        JOIN categories
          ON expenses.category_id = categories.id
       WHERE expenses.user_id = $1
         AND expenses.id = $2;
    SQL

    uid = uid_from_user_name(user)

    result = query(sql, uid, expense_id)
    result.ntuples > 0 ? tuple_to_expense(result.tuple(0)) : nil
  end

  def update_expense(expense, user)
    uid = uid_from_user_name(user)
    cat_id = cat_id_from_name(expense.category)

    sql = <<~SQL
      UPDATE expenses
      SET memo = $1, transaction_date = $2, transaction_type = $3,
          amount = $4, category_id = $5
      WHERE id = $6 AND user_id = $7;
    SQL

    query(sql, expense.memo, expense.date, expense.type, expense.amount, cat_id, expense.id, uid)
  end

  def categories
    result = query("SELECT * FROM categories ORDER BY id")
    result.map { |tuple| tuple["name"]}
  end

  def register_user(user, pass, first_name, balance)
    pass = BCrypt::Password.create(pass)

    user_account_sql = <<~SQL
      INSERT INTO user_accounts (first_name, initial_balance)
        VALUES ($1, $2)
        RETURNING id
    SQL

    result = query(user_account_sql, first_name, balance)
    uid = result[0]['id']

    login_data_sql = <<~SQL
      INSERT INTO user_login_data (user_id, user_name, password)
        VALUES ($1, $2, $3)
    SQL

    query(login_data_sql, uid, user, pass)
  end

  def duplicate_user?(user)
    result = query("SELECT user_name FROM user_login_data")

    result.each do |tuple|
      if tuple['user_name'].downcase == user.downcase
        return true
      end
    end
    false
  end

  def sign_in(user, pass)
    pwd_sql = "SELECT password FROM user_login_data WHERE user_name ILIKE $1"
    pwd_result = query(pwd_sql, user)
    bcrypt_pwd = ""
    if pwd_result.ntuples == 1
      hsh_pwd = pwd_result[0]['password']
      bcrypt_pwd = BCrypt::Password.new(hsh_pwd)
    end

    return nil unless bcrypt_pwd == pass

    uid = uid_from_user_name(user)
    user_data_sql = "SELECT first_name FROM user_accounts WHERE id = $1"
    user_data_result = query(user_data_sql, uid)

    first_name = user_data_result[0]['first_name']

    {user_name: user, first_name: first_name}
  end

  private

  def cat_id_from_name(name)
    cat_id_sql = "SELECT id FROM categories WHERE name = $1"
    cat_id_result = query(cat_id_sql, name)
    cat_id_result[0]['id']
  end

  def uid_from_user_name(user)
    uid_sql = "SELECT user_id FROM user_login_data WHERE user_name ILIKE $1"
    uid_result = query(uid_sql, user)
    uid_result[0]['user_id']
  end

  def tuple_to_expense(tuple, balance=nil)
    Expense.new(tuple['memo'], tuple['date'], tuple['type'],
                  tuple['amount'], tuple['category'], balance, tuple['id'])
  end

  def running_balance(current_balance, amount, type)
    case type
    when 'withdrawal' then (current_balance - amount).round(2)
    when 'deposit' then (current_balance + amount).round(2)
    end
  end
end