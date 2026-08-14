import sys
sys.path.insert(0, "/Users/fox/Documents/PROJECTS/M5/mlx/python")
import mlx.core as mx

a = mx.random.normal((8192, 8192))
b = mx.random.normal((8192, 8192))

print("Starting matmul...")
c = mx.matmul(a, b)
mx.eval(c)
print("Matmul done.")
