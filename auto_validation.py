import json
import os
import subprocess
from datetime import datetime
from zoneinfo import ZoneInfo
from collections import Counter

# Capture execution time
execution_time = datetime.now(ZoneInfo("America/New_York")).strftime("%H:%M %Z %B/%d/%Y")

#FQDN
BASE_HOST = os.environ.get("BASE_HOST", "https://status.staging.vyond-fedramp.org").rstrip("/")
FULL_PATH = f"{BASE_HOST}/phase-one"

# Read JSON file
with open("data.json", "r") as f:
    data = json.load(f)

# Initialize results storage and counters
ksi_results = []
result_counter = Counter()
method_counter = Counter()

# Process KSI Validation
for ksi in data["KSI Validation"]:
    for cap_key, cap in ksi["Critical Security Capability"].items():
        result = None
        evidence_output = []

        if cap["type"] == "script":
            script_info = cap["ref"][0]
            script_path = script_info["script"]
            script_name = os.path.basename(script_path).replace(".sh", "")
            evidence_file = f"./evidence/{script_name}.txt"

            try:
                process = subprocess.run(
                    ["bash", script_path],
                    capture_output=True,
                    text=True,
                    check=True
                )
                script_output = process.stdout.strip().splitlines()[-1]
                result = script_output == "True"

                if os.path.exists(evidence_file):
                    evidence_output = [{"text": evidence_file, "link": f"{FULL_PATH}/evidence/{script_name}.txt"}]
                else:
                    evidence_output = [{"text": "Evidence file not generated", "link": None}]
                    result = False

            except subprocess.CalledProcessError:
                result = False
                evidence_output = [{"text": "Script execution failed", "link": None}]

            method_counter["Auto Validation"] += 1

        elif cap["type"] == "attestation":
            ref_entry = cap["ref"][0] if cap["ref"] else {}
            ref_value = ref_entry.get("text") or ref_entry.get("script") or ""
            result = ref_value != "False"
            evidence_output = cap["ref"]
            method_counter["Attestation"] += 1

        result_counter["True" if result else "False"] += 1

        ksi_results.append({
            "KSI_Name": ksi["Name"],
            "KSI_Code": ksi["Code"],
            "Number": cap_key,
            "Desc": cap["desc"],
            "Type": cap["type"],
            "Result": result,
            "Note": cap["note"],
            "Evidence": evidence_output
        })

# Calculate ratios for executive summary
total_items = sum(result_counter.values())
true_ratio = result_counter["True"] / total_items * 100 if total_items else 0
false_ratio = result_counter["False"] / total_items * 100 if total_items else 0
auto_ratio = method_counter["Auto Validation"] / total_items * 100 if total_items else 0
attestation_ratio = method_counter["Attestation"] / total_items * 100 if total_items else 0

result_bg_class = "true-bg_class" if result_counter["False"] == 0 and total_items > 0 else "false-bg_class"

html_content = f"""
<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <title>KSI Validation Report</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        h1, h2 {{ color: #333; }}
        table {{ width: 100%; border-collapse: collapse; margin-bottom: 20px; }}
        th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        th {{ background-color: #f2f2f2; }}
        .true-bg_class {{ background-color: #d4edda; }}
        .false-bg_class {{ background-color: #f8d7da; }}
        .summary-table td:nth-child(1) {{ width: 20%; }}
        .executive-table td:nth-child(1) {{ width: 50%; }}
        .executive-table td:nth-child(2) {{ width: 50%; }}
    </style>
</head>
<body>
    <h1>KSI Validation Report</h1>
    <p>Generated at: {execution_time}</p>

    <h2>Summary of CSP and CSO</h2>
    <table class=\"summary-table\">
        <tr>
            <th>CSP</th><th>CSO</th><th>Impact Level</th><th>Package ID</th>
        </tr>
        <tr>
            <td>{data["CSP Summary"]["CSP"]}</td><td>{data["CSP Summary"]["CSO"]}</td><td>{data["CSP Summary"]["FedRAMP Impact Level"]}</td><td>{data["CSP Summary"]["FedRAMP Package ID"]}</td>
        </tr>
        <tr><td colspan=\"4\"><strong>System Description</strong></td></tr>
        <tr><td colspan=\"4\">{data["CSP Summary"]["System Description"]}</td></tr>
    </table>

    <h2>Executive Summary</h2>
    <table class=\"executive-table\">
        <tr><th>Metric</th><th>Value</th></tr>
        <tr><td>Total Items</td><td>{total_items}</td></tr>
        <tr><td>True/False Ratio</td><td class=\"{result_bg_class}\">True: {result_counter["True"]} ({true_ratio:.2f}%)<br>False: {result_counter["False"]} ({false_ratio:.2f}%)</td></tr>
        <tr><td>Auto Validation/Attestation Ratio</td><td>Auto Validation: {method_counter["Auto Validation"]} ({auto_ratio:.2f}%)<br>Attestation: {method_counter["Attestation"]} ({attestation_ratio:.2f}%)</td></tr>
    </table>

    <h2>Key Security Indicators and Validations</h2>
    <table class=\"ksi-table\">
        <tr><th>KSI</th><th>#</th><th>Capability Desc</th><th>Validation Method</th><th>Result</th><th>Note</th><th>Evidence</th></tr>
"""

for cap in ksi_results:
    validation_method = "Auto Validation" if cap["Type"] == "script" else "Attestation"
    result_text = "True" if cap["Result"] else "False"
    result_class = "true-bg_class" if cap["Result"] else "false-bg_class"

    evidence_html = ", ".join(
        f'<a href="{entry["link"]}" target="_blank">{os.path.basename(entry["text"] if "text" in entry else entry["script"])}</a>'
        if entry.get("link") else entry.get("text", entry.get("script"))
        for entry in cap["Evidence"]
    )

    html_content += f"""
        <tr>
            <td>{cap["KSI_Name"]} ({cap["KSI_Code"]})</td>
            <td>{cap["Number"]}</td>
            <td>{cap["Desc"]}</td>
            <td>{validation_method}</td>
            <td class=\"{result_class}\">{result_text}</td>
            <td>{cap["Note"]}</td>
            <td>{evidence_html}</td>
        </tr>
    """

html_content += """
    </table>
</body>
</html>
"""

with open("ksi_validation_report.html", "w") as f:
    f.write(html_content)

print("Report generated: ksi_validation_report.html")