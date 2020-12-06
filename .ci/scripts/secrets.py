import json
import sys

secrets = json.loads(sys.argv[1])
dotenv_path = sys.argv[2]

with open(dotenv_path, "a") as dotenv:
    for key, value in secrets.items():
        if key == "PULP_DOCS_KEY":
            # Test if the error only happens with PULP_DOCS_KEY
            print("Skipping PULP_DOCS_KEY")
            continue
        print(f"Setting {key} ...")
        dotenv.write(f"{key}={value}")
