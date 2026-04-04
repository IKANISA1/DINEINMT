import os
import re

DIR = 'dinein_app/lib/features/guest'

replacements = [
    (r"import '(\.\./)*core/models/([^']+)';", r"import 'package:db_pkg/models/\2';"),
    (r"import '(\.\./)*core/providers/([^']+)';", r"import 'package:dinein_app/core/providers/\2';"),
    (r"import '(\.\./)*core/router/([^']+)';", r"import 'package:dinein_app/core/router/\2';"),
    (r"import '(\.\./)*core/services/([^']+)';", r"import 'package:dinein_app/core/services/\2';"),
    (r"import '(\.\./)*core/infrastructure/([^']+)';", r"import 'package:dinein_app/core/infrastructure/\2';"),
    (r"import '(\.\./)*core/theme/([^']+)';", r"import 'package:ui/theme/\2';"),
    (r"import '(\.\./)*core/constants/([^']+)';", r"import 'package:core_pkg/constants/\2';"),
    (r"import '(\.\./)*shared/widgets/([^']+)';", r"import 'package:ui/widgets/\2';"),
    (r"import 'package:dinein_app/core/theme/", r"import 'package:ui/theme/"),
    (r"import 'package:dinein_app/shared/widgets/", r"import 'package:ui/widgets/"),
    (r"import '(\.\./)*core/models/", r"import 'package:db_pkg/models/"),
    (r"import '(\.\./)*shared/widgets/shared_widgets.dart';", r"import 'package:ui/widgets/shared_widgets.dart';"),
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
                
