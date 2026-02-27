Provide your CLI command here:

grep '"symbol": "TSLA"' transaction-log.txt | grep '"side": "sell"' | grep -o '"order_id": "[^"]*"' | grep -o '[0-9]*' | xargs -I{} curl -s "https://example.com/api/{}" >> output.txt

$ serve

grep '"symbol": "TSLA"' transaction-log.txt | grep '"side": "sell"' | grep -o '"order_id": "[^"]*"' | grep -o '[0-9]*' | xargs -I{} curl -s "http://localhost:8081/api/{}" >> output.txt

# Note:

https://example.com/api is used as a placeholder endpoint as provided in the problem statement.


Step 1 — from the file, grab only lines that mention TSLA
Step 2 — from those, keep only lines that are a sell
Step 3 — pull out just the order_id field
Step 4 — strip it down to just the number (e.g. 12346)
Step 5 — for each number, fire a GET request to the URL with that number plugged in
Step 6 — save all the responses into output.txt

So if you ran each step manually on paper:

After step 1: 2 lines (12346 and 12362)
After step 2: still 2 lines (both happen to be sells)
After step 3: "order_id": "12346" and "order_id": "12362"
After step 4: 12346 and 12362
After step 5: curl hits https://example.com/api/12346 then https://example.com/api/12362
After step 6: whatever those URLs return gets written to output.txt

The | (pipe) character is what connects each step, passing the output of one into the input of the next.