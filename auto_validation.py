import json
import os
import subprocess
from datetime import datetime
from zoneinfo import ZoneInfo

# Capture execution time
execution_time = datetime.now(ZoneInfo("America/New_York")).strftime("%H:%M %Z %B/%d/%Y")

#FQDN
BASE_HOST = os.environ.get("BASE_HOST", "https://status.staging.vyond-fedramp.org").rstrip("/")
FULL_PATH = f"{BASE_HOST}/phase-one/"

# Read JSON file
with open("data.json", "r") as f:
    data = json.load(f)

# Initialize results storage
ksi_results = []

# Process KSI Validation
for ksi in data["KSI Validation"]:
    ksi_entry = {
        "Name": ksi["Name"],
        "Code": ksi["Code"],
        "Capabilities": []
    }
    for cap_key, cap in ksi["Critical Security Capability"].items():
        result = None
        evidence = cap["ref"]

        if cap["type"] == "script":
            script_path = cap["ref"]
            script_name = os.path.basename(script_path).replace(".sh", "")
            evidence_file = f"./evidence/{script_name}.txt"

            # Execute script and capture output
            try:
                # Assume script echoes "True" or "False"
                process = subprocess.run(
                    ["bash", script_path],
                    capture_output=True,
                    text=True,
                    check=True
                )
                script_output = process.stdout.strip().splitlines()[-1]
                result = script_output == "True"

                # Check if evidence file was created by the script
                if os.path.exists(evidence_file):
                    evidence = evidence_file
                else:
                    evidence = "Evidence file not generated"
                    result = False

            except subprocess.CalledProcessError:
                result = False
                evidence = "Script execution failed"

        elif cap["type"] == "attestation":
            result = cap["ref"] != "False"
            if cap["ref"] in ["NA", "False"]:
                evidence = cap["ref"]

        ksi_entry["Capabilities"].append({
            "Number": cap_key,
            "Desc": cap["desc"],
            "Type": cap["type"],
            "Result": result,
            "Note": cap["note"],
            "Evidence": evidence
        })

    ksi_results.append(ksi_entry)

# Generate HTML
html_content = f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>KSI Validation Report</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            margin: 20px;
        }}
        h1, h2 {{
            color: #333;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
        }}
        th, td {{
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
        }}
        th {{
            background-color: #f2f2f2;
        }}
        .true-bg {{
            background-color: #d4edda;
        }}
        .false-bg {{
            background-color: #f8d7da;
        }}
        .summary-table td:nth-child(1) {{
            width: 20%;
        }}
        .ksi-table th:nth-child(1), .ksi-table td:nth-child(1) {{
            width: 5%;
        }}
        .ksi-table th:nth-child(2), .ksi-table td:nth-child(2) {{
            width: 30%;
        }}
        .ksi-table th:nth-child(3), .ksi-table td:nth-child(3) {{
            width: 15%;
        }}
        .ksi-table th:nth-child(4), .ksi-table td:nth-child(4) {{
            width: 10%;
        }}
        .ksi-table th:nth-child(5), .ksi-table td:nth-child(5) {{
            width: 30%;
        }}
        .ksi-table th:nth-child(6), .ksi-table td:nth-child(6) {{
            width: 10%;
        }}
    </style>
</head>
<body>
    <h1>KSI Validation Report</h1>
    <p>Generated at: {execution_time}</p>

    <h2>Summary of CSP and CSO</h2>
    <table class="summary-table">
        <tr>
            <th>CSP</th>
            <th>CSO</th>
            <th>Impact Level</th>
            <th>Package ID</th>
        </tr>
        <tr>
            <td>{data["CSP Summary"]["CSP"]}</td>
            <td>{data["CSP Summary"]["CSO"]}</td>
            <td>{data["CSP Summary"]["FedRAMP Impact Level"]}</td>
            <td>{data["CSP Summary"]["FedRAMP Package ID"]}</td>
        </tr>
        <tr>
            <td colspan="4"><strong>System Description</strong></td>
        </tr>
        <tr>
            <td colspan="4">{data["CSP Summary"]["System Description"]}</td>
        </tr>
    </table>

    <h2>Key Security Indicators and Validations</h2>
"""

# Add KSI Validation tables
for ksi in ksi_results:
    html_content += f"""
    <table class="ksi-table">
        <tr>
            <th colspan="6">{ksi["Name"]} ({ksi["Code"]})</th>
        </tr>
        <tr>
            <th>#</th>
            <th>Capability Desc</th>
            <th>Validation Method</th>
            <th>Result</th>
            <th>Note</th>
            <th>Evidence</th>
        </tr>
    """
    for cap in ksi["Capabilities"]:
        validation_method = "Auto Validation" if cap["Type"] == "script" else "Attestation"
        result_text = "True" if cap["Result"] else "False"
        result_class = "true-bg" if cap["Result"] else "false-bg"

        # Handle evidence hyperlink
        evidence_text = cap["Evidence"]
        if cap["Type"] == "script" and os.path.exists(cap["Evidence"]):
            evidence_file = os.path.basename(cap["Evidence"])
            evidence_text = f'<a href="{FULL_PATH}{cap["Evidence"]}" target="_blank">{evidence_file}</a>'
        elif cap["Type"] == "attestation" and cap["Evidence"] not in ["NA", "False"]:
            # Handle multiple files in ref (e.g., comma-separated)
            if ", " in cap["Evidence"]:
                files = cap["Evidence"].split(", ")
                evidence_text = ", ".join(
                    f'<a href="{FULL_PATH}{f}" target="_blank">{os.path.basename(f)}</a>' for f in files
                )
            else:
                evidence_file = os.path.basename(cap["Evidence"])
                evidence_text = f'<a href="{FULL_PATH}{cap["Evidence"]}" target="_blank">{evidence_file}</a>'

        html_content += f"""
        <tr>
            <td>{cap["Number"]}</td>
            <td>{cap["Desc"]}</td>
            <td>{validation_method}</td>
            <td class="{result_class}">{result_text}</td>
            <td>{cap["Note"]}</td>
            <td>{evidence_text}</td>
        </tr>
        """
    html_content += "</table>"

html_content += """
</body>
</html>
"""

# Write HTML to file
with open("ksi_validation_report.html", "w") as f:
    f.write(html_content)

print("Report generated: ksi_validation_report.html")