# like a javascript object, just assign any properties
class OpenStruct(object):
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

    def __len__(self):
        return self.__dict__.__len__()

    def __getitem__(self, key):
        if key in self.__dict__:
            return self.__dict__[key]
        else:
            return None

    def __setitem__(self, key, value):
        self.__dict__[key] = value
        return value
        
    def __delitem__(self, key):
        return self.__dict__.__delitem__(key)
        
    def __iter__(self):
        return self.__dict__.__iter__()
        
    def __contains__(self, item):
        return self.__dict__.__contains__(item)
    
    def keys(self):
        return self.__dict__.keys()
    
    # values(), items(), has_key(), get(), clear(), setdefault(), iterkeys(), itervalues(), iteritems()
    
    # allow for multi-value properties. If a property is set once,
    # it's value is just a value. If it's set again, it becomes a
    # list that accumulates any subsequently set values.
    def set_or_append(self, key, value):
        if key in self:
            current_value = self.__dict__[key]
            if type(current_value) is list:
                current_value.append(value)
            else:
                new_value = [current_value, value]
                self.__dict__[key] = new_value
            return self.__dict__[key]
        else:
            return self.__setitem__(key, value)

    # get the value of a property as a list.
    def get_as_list(self, key):
        if key not in self.__dict__:
            return []
        value = self.__dict__[key]
        if type(value) is list:
            return value
        else:
            return [value]
