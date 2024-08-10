import configparser
import sys

class ModelConfig(configparser.ConfigParser):
    def __init__(self,
                 config_file,
                 defaults={"MaxTrain": sys.maxsize,
                           "MaxTest": sys.maxsize,
                           "Flatten": '0',
                           "ShouldTest": '0'},
                 **kwargs):
        super().__init__(defaults= defaults,
                         converters= {'any': _auto_cast, 'list': _aslist},
                         **kwargs)
        with open(config_file, 'r') as f:
            cfgContent = f.read()
        cfgContent = "[NN]\n" + cfgContent
        self.read_string(cfgContent)
        self.config = self['NN']
    
    def __getattr__(self, name: str):
        val = self.config.get(name)
        return _auto_cast(val)

def _auto_cast(value):
    
    if value is None:
        return value
    vals = value.split(',')
    if len(vals) > 1:
        return [_auto_cast(x) for x in vals]
    try:
        return int(value)
    except ValueError:
        pass
    try:
        return float(value)
    except ValueError:
        pass
    return value

def _aslist(value):
    if value is None:
        return [value]
    vals = value.split(',')
    return [ _auto_cast(x) for x in vals ]