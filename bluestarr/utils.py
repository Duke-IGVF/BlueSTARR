
## keras.backend.int_shape() got dropped after v2.15
def int_shape(x):
    s = x.shape
    if not isinstance(s, tuple):
        s = tuple(s.as_list())
    return s
