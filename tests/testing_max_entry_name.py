import shutil

terminal_width = shutil.get_terminal_size().columns
a = "a" * terminal_width
print(a)
