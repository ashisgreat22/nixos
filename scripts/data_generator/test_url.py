import os
from openai import OpenAI

# Case 1: URL with /v1
print("--- Case 1: /v1 ---")
client = OpenAI(api_key="sk-test", base_url="http://127.0.0.1:8045/v1")
try:
    client.chat.completions.create(model="test", messages=[{"role":"user","content":"hi"}])
except Exception as e:
    print(e)

# Case 2: URL without /v1 (Root)
print("\n--- Case 2: Root ---")
client = OpenAI(api_key="sk-test", base_url="http://127.0.0.1:8045")
try:
    client.chat.completions.create(model="test", messages=[{"role":"user","content":"hi"}])
except Exception as e:
    print(e)
