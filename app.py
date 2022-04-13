from flask import Flask,jsonify,make_response
from datetime import datetime
app = Flask(__name__)

@app.route('/')
def index():
    return make_response(jsonify({'time': datetime.now().strftime("%d/%m/%Y, %H:%M:%S")}), 200)

@app.route('/healthz')
def healthz():
    return make_response(jsonify({'status':'up'}), 200)

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8000, debug=True)
