import collections
import pymysql

#RDS_URL = "bmorebikeshare.cyi1fe7cdnil.us-east-1.rds.amazonaws.com"
RDS_URL = "127.0.0.1"

RouteStatus = collections.namedtuple("cancelled_runs", ("trip_id, timestamp, status"))

class Database:
    def __init__(self):
        self.db = pymysql.connect(RDS_URL, "root", "password", "bmorebikeshare")
        self.cursor = self.db.cursor()
        #self.create_table()

    def _run_sql(self, command, *args):
        try:
            print(command, *args)
            self.cursor.execute(command, *args)
            self.db.commit()
            return self.cursor.fetchall()
        except pymysql.err.ProgrammingError as ex:
            self.db.rollback
            raise

    def insert_routestatus(self, entrytime, trip_id, status):
        self._run_sql(("INSERT INTO routestatus (entrytime, trip_id, status) VALUES (%s, %s, %s)"
                       " ON DUPLICATE KEY UPDATE trip_id = trip_id"), (entrytime, trip_id, status))

    def create_table(self):
        print("Entering create_table")
        self._run_sql(("CREATE TABLE routestatus ("
                       "trip_id INT, "
                       "entrytime INT,"
                       "status INT,"
                       "PRIMARY KEY (trip_id))"))