# Lazy objects, for the serializer to find them we put them here

class LazyDriver(object):
    _driver = None

    @classmethod
    def get(cls):
        import os
        if cls._driver is None:
            from pyvirtualdisplay import Display
            display = Display(visible=0, size=(800, 600))
            display.start()
            from selenium import webdriver
            cls._driver = webdriver.Chrome()
        return cls._driver


class LazyPool(object):
    _pool = None
    
    @classmethod
    def get(cls):
        if cls._pool is None:
            import urllib3
            cls._pool = urllib3.PoolManager()
        return cls._pool
