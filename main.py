prices = {'apple': 0.40, 'banana': 0.50}
my_purchase = {
    'apple': 1,
    'banana': 6}
grocery_bill = sum(prices[frit] * my_purchase[fruit]
                   for fruit in my_purchase)
print (f'I owe the grocer ${grocery_bill:.2f}')