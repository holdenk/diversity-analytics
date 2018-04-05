# Lazy objects, for the serializer to find them we put them here

class LazyDriver(object):
    _driver = None

    @classmethod
    def get(cls):
        import os
        if cls._driver is None:
            from selenium import webdriver
            # Configure headless mode
            chrome_options = webdriver.ChromeOptions() #Oops
            chrome_options.add_argument('headless')
            chrome_options.add_argument('--verbose')
            chrome_options.add_argument('--ignore-certificate-errors')
            log_path = "/tmp/chromelogpanda{0}".format(os.getpid())
            if not os.path.exists(log_path):
                os.mkdir(log_path)
            chrome_options.add_argument("--log-path {0}".format(log_path))
            cls._driver = webdriver.Chrome(chrome_options=chrome_options)
        return cls._driver


class LazyPool(object):
    _pool = None
    
    @classmethod
    def get(cls):
        if cls._pool is None:
            import urllib3
            cls._pool = urllib3.PoolManager()
        return cls._pool
