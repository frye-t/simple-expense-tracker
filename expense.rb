class Expense
  attr_reader :memo, :date, :type, :amount, :category, :balance, :id

  def initialize(memo, date, type, amount, category, balance=nil, id=nil)
    @memo = memo
    @date = date
    @type = type
    @amount = amount
    @category = category
    @balance = balance
    @id = id
  end

  def to_s
    "Memo: #{memo}"\
    "Date: #{date}"\
    "Type: #{type}"\
    "Amount: #{amount}"\
    "Category: #{category}"\
    "Balance: #{balance}"\
    "ID: #{id}"
  end
end