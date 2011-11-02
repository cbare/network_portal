# like a javascript object, just assign any properties
class OpenStruct:
    def __init__(self, **dic):
        self.__dict__.update(dic)

    def __getattr__(self, key):
        if key in self.__dict__:
            return self.__dict__[key]
        else:
            return None
            # raise AttributeError, key

    def __setattr__(self, key, value):
        self.__dict__[key] = value
        return value

    def __str__(self):
        result = "<"
        result += ", ".join( ["%s:%s" % (str(key), str(self.__dict__[key])) for key in self.__dict__] )
        result += ">"
        return result

    def __repr__(self):
        return str(self)
