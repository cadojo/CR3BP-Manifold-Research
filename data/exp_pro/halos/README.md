# How are the Halo CSV files formatted?

The columns from left to right are: 
1.  Nondimensional mass parameter
2.  Lagrange point (1 or 2)
3.  Nondimensional Z amplitude
4.  Jacobi Constant
5.  Nondimensional orbital period
6.  Nondimensional X
7.  Nondimensional Y
8.  Nondimensional Z
9.  Nondimensional Ẋ
10. Nondimensional Ẏ
11. Nondimensional Ż

You can load this data into:
* MATLAB with `readtable('path/to/file.csv')`
* Julia with `DataFrame(CSV.File("path/to/file.csv"))`
