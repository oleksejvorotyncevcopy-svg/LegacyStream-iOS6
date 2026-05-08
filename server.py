import os
import requests
import yt_dlp
from flask import Flask, jsonify, request, Response
import hashlib
import string
import random
import urllib.parse

SS_URL = "http://127.0.0.1:4040" 
SS_USER = "your_username_in_aerosonic"
SS_PASS = "your_password_in_aerosonic"  

NODE_PATH = '/opt/homebrew/bin/node' 
if os.path.exists(NODE_PATH):
    os.environ["PATH"] += os.pathsep + os.path.dirname(NODE_PATH)

app = Flask(__name__)
STREAM_CACHE = {}

def get_ss_auth():
    salt = ''.join(random.choices(string.ascii_letters + string.digits, k=6))
    token = hashlib.md5((SS_PASS + salt).encode('utf-8')).hexdigest()
    return f"u={SS_USER}&t={token}&s={salt}&v=1.15.0&c=RetroMusic&f=json"

@app.route('/search')
def search():
    query = request.args.get('q')
    if not query: return jsonify([])
    url = f"https://itunes.apple.com/search?term={query}&entity=song&limit=15"
    try:
        r = requests.get(url)
        return jsonify([{"title": i.get('trackName'), "artist": i.get('artistName'), 
                         "id": f"{i.get('artistName')} {i.get('trackName')}"} 
                        for i in r.json().get('results', [])])
    except: return jsonify([])

@app.route('/track')
def get_track():
    search_str = request.args.get('id')
    ydl_opts = {
        'format': '18/best[ext=mp4]', 
        'noplaylist': True, 'quiet': True, 'no_warnings': True, 'nocheckcertificate': True
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(f"ytsearch1:{search_str}", download=False)
            entry = info['entries'][0]
            video_id = entry['id']
            STREAM_CACHE[video_id] = {'url': entry['url'], 'headers': entry.get('http_headers', {})}
            return jsonify({"stream_url": f"http://{request.host}/proxy?vid={video_id}"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/proxy')
def proxy():
    vid = request.args.get('vid')
    if vid not in STREAM_CACHE: return "Not found", 404
    stream_info = STREAM_CACHE[vid]
    
    headers = stream_info['headers'].copy() 
    if request.headers.get('Range'): headers['Range'] = request.headers.get('Range')

    r = requests.get(stream_info['url'], headers=headers, timeout=15)
    resp_headers = {'Content-Type': 'audio/mp4', 'Accept-Ranges': 'bytes'}
    if 'Content-Length' in r.headers: resp_headers['Content-Length'] = r.headers['Content-Length']
    if 'Content-Range' in r.headers: resp_headers['Content-Range'] = r.headers['Content-Range']
    return Response(r.content, status=r.status_code, headers=resp_headers)

@app.route('/ss_search')
def ss_search():
    query = request.args.get('q')
    if not query: return jsonify([])

    safe_query = urllib.parse.quote(query)
    
    auth = get_ss_auth()
    url = f"{SS_URL}/rest/search3?{auth}&query={safe_query}&songCount=20"
    

    try:
        r = requests.get(url, timeout=10)
        data = r.json()
        
        
        resp = data.get('subsonic-response', {})
        search_result = resp.get('searchResult3') or resp.get('searchResult2') or {}
        songs = search_result.get('song', [])
        
        
        
        results = []
        for s in songs:
            results.append({
                "title": s.get('title', 'Unknown'), 
                "artist": s.get('artist', 'Unknown'), 
                "id": str(s.get('id'))
            })
        return jsonify(results)
    except Exception as e:
        print(f"!!! SERVER ERROR: {e}")
        return jsonify([])
@app.route('/ss_track')
def get_ss_track():
    ss_id = request.args.get('id')
    return jsonify({"stream_url": f"http://{request.host}/ss_proxy?id={ss_id}"})

@app.route('/ss_proxy')
def ss_proxy():
    ss_id = request.args.get('id')
    url = f"{SS_URL}/rest/stream?{get_ss_auth()}&id={ss_id}&format=mp3"
    
    headers = {}
    if request.headers.get('Range'): headers['Range'] = request.headers.get('Range')

    r = requests.get(url, headers=headers, timeout=15)
    resp_headers = {'Content-Type': 'audio/mp3', 'Accept-Ranges': 'bytes'}
    if 'Content-Length' in r.headers: resp_headers['Content-Length'] = r.headers['Content-Length']
    if 'Content-Range' in r.headers: resp_headers['Content-Range'] = r.headers['Content-Range']
    return Response(r.content, status=r.status_code, headers=resp_headers)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
