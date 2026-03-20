import os, re, time, csv
from flask import Flask, render_template, request, jsonify
from celery import Celery
from netmiko import ConnectHandler
from dotenv import load_dotenv

load_dotenv()
app = Flask(__name__)
app.config['CELERY_BROKER_URL'] = os.getenv('REDIS_URL', 'redis://redis:6379/0')
celery = Celery(app.name, broker=app.config['CELERY_BROKER_URL'])

LOG_FILE = "update_progress.log"

@celery.task(bind=True)
def run_zte_bulk_update(self, data):
    olt_params = {
        "device_type": "zte_zxros",
        "host": data['host'],
        "port": int(data['port']),
        "username": data['username'],
        "password": data['password'],
        "global_delay_factor": 2,
    }
    port_range = range(1, 17) if data['card_type'] == "GTGH" else range(1, 9)
    try:
        with open(LOG_FILE, "w") as f: f.write("Connecting to OLT...")
        net_connect = ConnectHandler(**olt_params)
        net_connect.enable()
        prompt = net_connect.find_prompt()
        net_connect.send_command("terminal length 0")
        for card in [1, 2]:
            for port in port_range:
                port_path = f"1/{card}/{port}"
                with open(LOG_FILE, "a") as f: f.write(f"\nScanning {port_path}...")
                output = net_connect.send_command(f"show gpon onu state gpon-olt_{port_path}", read_timeout=60)
                onu_matches = re.findall(r"({}:\d+)".format(port_path), output)
                working_onus = [m for m in onu_matches if "working" in output.split(m)[1].split('\n')[0].lower()]
                for full_id in working_onus:
                    onu_num = full_id.split(':')[-1]
                    with open(LOG_FILE, "a") as f: f.write(f"\nConfiguring {full_id}...")
                    net_connect.send_config_set([
                        f"pon-onu-mng {full_id}",
                        f"tr069-mgmt 1 acs {data['acs_url']}",
                        "tr069-mgmt 1 inform enable",
                        "exit",
                        f"interface gpon-olt_{port_path}",
                        f"onu reboot {onu_num}",
                        "exit"
                    ], cmd_verify=False)
                net_connect.send_command("write", expect_string=prompt)
        with open(LOG_FILE, "a") as f: f.write("\n✅ ALL TASKS COMPLETE.")
        net_connect.disconnect()
    except Exception as e:
        with open(LOG_FILE, "a") as f: f.write(f"\n❌ ERROR: {str(e)}")

@app.route('/')
def index(): return render_template('index.html')

@app.route('/start', methods=['POST'])
def start():
    task = run_zte_bulk_update.apply_async(args=[request.json])
    return jsonify({"task_id": task.id})

@app.route('/log')
def get_log():
    if os.path.exists(LOG_FILE):
        with open(LOG_FILE, "r") as f: return "".join(f.readlines()[-15:])
    return "Waiting..."

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
