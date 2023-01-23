require 'pg'

require_relative 'expense'

class DatabasePersistence 
  def initialize(logger)
    @db = PG.connect(dbname: "expenses")
    @logger = logger
  end

  def verify_connection
    puts "Connected to:"
    puts @db
  end

  def query(statement, *params)
    @logger.info("#{statement}: #{params}")
    @db.exec_params(statement, params)
  end

  def all_expenses(user)
    expenses_sql = <<~SQL
      SELECT expenses.id, expenses.memo,
             expenses.transaction_date AS date, expenses.transaction_type AS type,
             expenses.amount, categories.name AS category
        FROM user_accounts JOIN user_login_data
          ON user_accounts.id = user_login_data.user_id
        JOIN expenses
          ON expenses.user_id = user_login_data.user_id
        JOIN categories
          ON expenses.category_id = categories.id
        ORDER BY date, expenses.memo;
    SQL

    expense_result = query(expenses_sql)

    balance_result = query("SELECT initial_balance FROM user_accounts")
    balance = balance_result[0]['initial_balance'].to_f

    expenses = expense_result.map do |tuple|
      balance = running_balance(balance, tuple['amount'].to_f, tuple['type'])
      tuple_to_expense(tuple, balance)
    end
  end

  def add_expense(expense, user)
    uid = uid_from_user_name(user)
    cat_id = cat_id_from_name(expense.category)

    pp expense

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
      WHERE user_login_data.user_name = $1
      AND expenses.id = $2;
    SQL

    result = query(sql, user, expense_id)
    tuple_to_expense(result.tuple(0))
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

  private

  def cat_id_from_name(name)
    cat_id_sql = "SELECT id FROM categories WHERE name = $1"
    cat_id_result = query(cat_id_sql, name)
    cat_id_result[0]['id']
  end

  def uid_from_user_name(user)
    uid_sql = "SELECT user_id FROM user_login_data WHERE user_name = $1"
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