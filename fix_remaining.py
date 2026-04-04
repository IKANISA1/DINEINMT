import os
import re

DIR = 'dinein_app/lib/features/guest'

replacements = [
    (r"import '(\.\./)*core/config/([^']+)';", r"import 'package:core_pkg/config/\2';"),
    (r"import 'package:dinein_app/core/services/support_contact_service.dart';", r"import 'package:db_pkg/services/support_contact_service.dart';"),
]

for root, _, files in os.walk(DIR):
    for f in files:
        if not f.endswith('.dart'):
            continue
        filepath = os.path.join(root, f)
        with open(filepath, 'r') as fp:
            content = fp.read()
            
        new_content = content
        for pattern, repl in replacements:
            new_content = re.sub(pattern, repl, new_content)
            
        if new_content != content:
            with open(filepath, 'w') as fp:
                fp.write(new_content)
                
