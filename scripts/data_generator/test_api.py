import os
from dotenv import load_dotenv
from openai import OpenAI
import openai

load_dotenv()

client = OpenAI(
    api_key=os.getenv("API_KEY"),
    base_url=os.getenv("BASE_URL")
)

print(f"DEBUG: BASE_URL='{os.getenv('BASE_URL')}'")
print(f"DEBUG: API_KEY='{os.getenv('API_KEY')[:10]}...'")

try:
    print("Testing simple 'Hello' prompt...")
    response = client.chat.completions.create(
        model=os.getenv("MODEL_NAME"),
        messages=[{"role": "user", "content": "Hello, are you working?"}],
        max_tokens=50
    )
    print("Success!")
    print(response.choices[0].message.content)
except openai.APIStatusError as e:
    print(f"Error HTTP {e.status_code}: {e.body}")
except Exception as e:
    print(f"Error: {e}")
