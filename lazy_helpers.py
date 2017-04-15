# Lazy objects, for the serializer to find them we put them here

class LazyDriver(object):
    _driver = None
    
    def get(self):
        if self._driver is None:
            from selenium import webdriver
            self._driver = webdriver.Firefox()
        return self._driver


class LazyPool(object):
    _pool = None
    
    @classmethod
    def get(cls):
        if cls._pool is None:
            import urllib3
            cls._pool = urllib3.PoolManager()
        return cls._pool
