import csv
import subprocess
import os

user_pool_id = os.getenv("AWS_COGNITO_POOL_ID")
csv_file_path = "/home/tpelizoni/Storage/usuarios.csv"

with open(csv_file_path, mode="r") as csv_file:
    csv_reader = csv.DictReader(csv_file)
    for row in csv_reader:
        email = row["email"]
        cpf = row["cpf"]
        nome = row["nome"]
        password = row["password"].strip()

        username = email.split("@")[0]

        create_user_command = [
            "aws", "cognito-idp", "admin-create-user",
            "--user-pool-id", user_pool_id,
            "--username", username,
            "--user-attributes",
            f"Name=email,Value={email}",
            f"Name=custom:cpf,Value={cpf}",
            f"Name=custom:nome,Value={nome}",
            f"Name=custom:data_nascimento,Value={row['data_nascimento']}",
            "--temporary-password", password,
            "--message-action", "SUPPRESS"
        ]

        try:
            result = subprocess.run(
                create_user_command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                check=True,
                timeout=30
            )
            print(f"Usuário {username} criado com sucesso. Saída: {result.stdout}")
        except subprocess.CalledProcessError as e:
            print(f"Erro ao criar o usuário {nome}: {e.stderr}")
        except subprocess.TimeoutExpired:
            print(f"Tempo limite excedido ao criar o usuário {nome}.")
