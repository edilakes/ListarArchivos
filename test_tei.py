import requests

def embed_text(text):
    url = "http://194.61.28.46:8080/v1/embeddings"
    headers = {"Content-Type": "application/json"}
    payload = {
        "model": "intfloat/multilingual-e5-large",
        "input": text
    }
    response = requests.post(url, headers=headers, json=payload)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Error {response.status_code}: {response.text}")
        return None

res = embed_text("prueba de concepto")
if res and 'data' in res:
    print("SUCCESS")
    print("Vector length:", len(res['data'][0]['embedding']))
else:
    print("FAILED")
