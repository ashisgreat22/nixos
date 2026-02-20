"""
 Search Engine: Brave Search API
"""

import json
import os
from urllib.parse import quote

# About the engine
about = {
    "website": "https://brave.com/search/api/",
    "use_official_api": True,
    "require_api_key": True,
    "results": "JSON",
}

categories = ['general', 'web']
paging = True
max_page = 10
page_size = 20

# API Endpoint
base_url = "https://api.search.brave.com/res/v1/web/search"

def request(query, params):
    # Get key from environment
    api_key = os.getenv('BRAVE_API_KEY')
    
    # Brave expects offset 0-9 for pages
    pageno = min(params.get('pageno', 1), 10)
    offset = pageno - 1
    
    # Simple query string construction with proper quoting
    # Using 'x-subscription-token' (lowercase) which was verified to work
    params['url'] = f"{base_url}?q={quote(query)}&count=20&offset={offset}"
    
    params['headers'] = {
        'x-subscription-token': api_key,
        'Accept': 'application/json'
    }
    
    params['method'] = 'GET'
    
    # Clean up SearXNG defaults to prevent interference
    if 'data' in params: del params['data']
    if 'params' in params: del params['params']
    
    return params

def response(resp):
    results = []
    data = json.loads(resp.text)
    
    # The Brave API returns 'web' results
    web_results = data.get('web', {}).get('results', [])
    
    for item in web_results:
        results.append({
            'url': item.get('url'),
            'title': item.get('title'),
            'content': item.get('description'),
        })
        
    return results
