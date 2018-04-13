# Lazy objects, for the serializer to find them we put them here

class LazyDriver(object):
    _driver = None

    @classmethod
    def get(cls):
        import os
        if cls._driver is None:
            from pyvirtualdisplay import Display
            cls._display = display
            display = Display(visible=0, size=(1024, 768))
            display.start()
            from selenium import webdriver
            # Configure headless mode
            chrome_options = webdriver.ChromeOptions() #Oops
            chrome_options.add_argument('--verbose')
            chrome_options.add_argument('--ignore-certificate-errors')
            log_path = "/tmp/chromelogpanda{0}".format(os.getpid())
            if not os.path.exists(log_path):
                os.mkdir(log_path)
            chrome_options.add_argument("--log-path {0}/log.txt".format(log_path))
            chrome_options.add_argument("--no-sandbox")
            chrome_options.add_argument("--disable-setuid-sandbox")
            cls._driver = webdriver.Chrome(chrome_options=chrome_options)
        return cls._driver

    @classmethod
    def reset(cls):
        cls._display.stop()
        cls._driver.Dispose()


class LazyPool(object):
    _pool = None
    
    @classmethod
    def get(cls):
        if cls._pool is None:
            import urllib3
            cls._pool = urllib3.PoolManager()
        return cls._pool
