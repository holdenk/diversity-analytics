# Lazy objects, for the serializer to find them we put them here

class LazyDriver(object):
    _driver = None

    @classmethod
    def get(cls):
        if cls._driver is None:
            from selenium import webdriver
	    options = webdriver.ChromeOptions()
            options.add_argument('headless')
            cls._driver = webdriver.Chrome(options)
        return cls._driver


class LazyPool(object):
    _pool = None
    
    @classmethod
    def get(cls):
        if cls._pool is None:
            import urllib3
            cls._pool = urllib3.PoolManager()
        return cls._pool
