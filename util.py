def is_sorted(v):
    return all(v[i] < v[i + 1] for i in range(len(v) - 1))
