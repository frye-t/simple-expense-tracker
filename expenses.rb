require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'
require 'date'

require_relative 'database_persistence'
require_relative 'expense'

# Setup Session if using
configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  @user_name = session[:user_name]
  @storage = DatabasePersistence.new(logger)
  session[:user_name] = 'PetFrog'
end

# View Helpers
helpers do
  def balance_class(expense)
    balance = expense.balance.to_f
    if balance < 0
      "negative"
    elsif balance < 100
      "sub-100"
    elsif balance = nil
      ""
    end
  end

  def amount_class(expense)
    expense.type
  end
end

get '/' do
  redirect '/expenses'
end

get '/expenses' do
  @expenses = @storage.all_expenses(@user_name)
  if @expenses.size > 0
    @start_date = @expenses[0].date
    @end_date = @expenses[-1].date
  else
    @start_date = Date.today
    @end_date = Date.today
  end
  erb :expenses
end

get '/add-expense' do  
  @categories_list = @storage.categories
  erb :add_expense
end

def error_for_memo(memo)
  if !(1..30).cover? memo.size
    "Memo must be between 1 and 30 characters"
  end
end

post '/add-expense' do
  memo = params[:memo].strip
  amount = params[:amount]
  category = params[:category]
  date = params[:date]

  case category
  when "Income" then 
    type = "deposit"
    exp_type = "Income"
  else 
    type = "withdrawal"
    exp_type = "Expense"
  end

  error = error_for_memo(memo)
  if error
    session[:error] = error
    erb :add_expense
  else
    new_expense = Expense.new(memo, date, type, amount, category)
    @storage.add_expense(new_expense, @user_name)

    session[:success] = "#{exp_type} for #{memo} added!"
    redirect '/expenses'
  end
end

get '/edit-expense/:expense_id' do
  expense = @storage.single_expense(params[:expense_id], @user_name)
  @memo = expense.memo
  @date = expense.date
  @amount = expense.amount
  @category = expense.category
  @id = expense.id

  @categories_list = @storage.categories

  erb :edit_expense
end

post '/edit-expense/:expense_id' do
  memo = params[:memo].strip
  amount = params[:amount]
  category = params[:category]
  date = params[:date]
  id = params[:expense_id]

  case category
  when "Income" then 
    type = "deposit"
    exp_type = "Income"
  else 
    type = "withdrawal"
    exp_type = "Expense"
  end
  error = error_for_memo(memo)
  if error
    session[:error] = error
    erb :edit_expense
  else
    expense = Expense.new(memo, date, type, amount, category, nil, id)
    @storage.update_expense(expense, @user_name)

    session[:success] = "#{exp_type} for #{memo} updated!"
    redirect '/expenses'
  end  
end

post '/delete-expense/:expense_id' do
  expense_id = params[:expense_id]
  @storage.delete_expense(expense_id)
  session[:success] = "#{params[:memo]} deleted."
  redirect '/expenses'
end

get '/search' do
  term = params[:term]
  start_date = params[:start_date]
  end_date = params[:end_date]
  @search = true

  @expenses = @storage.search(term, start_date, end_date, @user_name)

  if @expenses.size > 0
    @start_date = @expenses[0].date
    @end_date = @expenses[-1].date
  else
    @start_date = Date.today
    @end_date = Date.today
  end  
  erb :expenses
end

not_found do; end