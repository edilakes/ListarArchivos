import os
import yaml
from pymongo import MongoClient, UpdateOne
from datetime import datetime, timezone
import sys

MONGO_URI = "mongodb://edilakes:Mongodb.09@194.61.28.46:27017/"
DB_NAME = "itheca"
COLLECTION_NAME = "knowledge_base"
MARKDOWN_DIR = r"e:\OneDrive\MiCodigo\GitHub\ListarArchivos\Markdown"

def run_test():
    client = MongoClient(MONGO_URI)
    db = client[DB_NAME]
    col = db[COLLECTION_NAME]
    
    files = []
    for root, _, fnames in os.walk(MARKDOWN_DIR):
        for f in fnames:
            if f.endswith(".md"):
                files.append(os.path.join(root, f))
            if len(files) >= 10: break
        if len(files) >= 10: break

    batch = []
    for f in files:
        with open(f, 'r', encoding='utf-8') as file:
            content = file.read()
        
        batch.append(UpdateOne(
            {"metadata.file_path": f},
            {"$set": {"content": content, "test": True}},
            upsert=True
        ))
    
    print(f"Probando bulk_write con {len(batch)} documentos...")
    res = col.bulk_write(batch)
    print(f"Resultado: nUpserted={res.upserted_count}, nModified={res.modified_count}")
    client.close()

if __name__ == "__main__":
    try:
        run_test()
    except Exception as e:
        print(f"Crashed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
