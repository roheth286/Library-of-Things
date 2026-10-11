import os
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5433")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")
DB_NAME = os.getenv("DB_NAME", "library_of_things")

def get_db_connection(isolation_level=None):
    """
    Returns a psycopg2 database connection.
    Optionally sets isolation_level (e.g., psycopg2.extensions.ISOLATION_LEVEL_READ_COMMITTED
    or ISOLATION_LEVEL_SERIALIZABLE).
    """
    conn = psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        dbname=DB_NAME
    )
    if isolation_level is not None:
        conn.set_isolation_level(isolation_level)
    return conn

def execute_query(query: str, params: tuple = None, fetch_one: bool = False, fetch_all: bool = True):
    """Utility helper to run SELECT queries returning dict records."""
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(query, params)
            if fetch_one:
                return cur.fetchone()
            if fetch_all:
                return cur.fetchall()
            return None
    finally:
        conn.close()
