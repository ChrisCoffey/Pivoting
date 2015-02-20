Pivoting
========
 A CoffeeScript library for dynamically pivoting & aggregating arbitrary data sets. 
 

## What Is This?

Pivoting is a small javascript library (well actually coffeescript) that allows you to take an arbitrary JSON data set, define dimensions (what you can group by) and measures (what you can aggregate), select an aggregate operator like Max, Min, Average, Sum, ... & create a new projection of the data set. It works by virtue of JavaScript objects actually being maps of String => Data & key based lookups into the objects.

The aggregate function library is really small right now, handling just:
 
 - Max
 - Min
 - Count
 - Sum
 - Average

However, those operators coupled with the dynamic reaggregation & NvD3's nice css filtration (broken right now) allows for an extremely smooth user experience when exploring their data. This is possible because the entire data set is kept in the browser's cache, so the only call to an external service occurs during the initial data fetch. After that it's all local!

## Running it

As mentioned above, this is still pretty broken since I've pulled it from an old code-base & tried to revive it. However, the aggregations work & can be sen using the "Total Set Aggregates" tab. "Export to CSV" & "My Views" also work, but only export to CSV is interesting.

To start this up, clone the repo then open Latency.scala.html from Chrome or another browser. The data generation is randomized but specific to the restaurant domain so you should see some interesting values.


## What's Next?
 1. Fix Visualizations
 2. Add Additional Aggregates
 3. Add Additional Visualizations



 
 
