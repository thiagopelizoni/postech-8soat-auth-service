import csv
import boto3
import os

user_pool_id = os.getenv("AWS_COGNITO_POOL_ID")
csv_file_path = "/home/tpelizoni/Storage/usuarios.csv"

client = boto3.client('cognito-idp')

with open(csv_file_path, mode="r") as csv_file:
    csv_reader = csv.DictReader(csv_file)
    for row in csv_reader:
        email = row["email"]
        cpf = row["cpf"]
        nome = row["nome"]
        password = row["password"].strip()

        username = email.split("@")[0]

        try:
            try:
                client.admin_delete_user(
                    UserPoolId=user_pool_id,
                    Username=username
                )
                print(f"Usuário {username} excluído com sucesso.")
            except client.exceptions.UserNotFoundException:
                print(f"Usuário {username} não encontrado. Criando um novo.")

            client.admin_create_user(
                UserPoolId=user_pool_id,
                Username=username,
                UserAttributes=[
                    {"Name": "email", "Value": email},
                    {"Name": "email_verified", "Value": "true"},
                    {"Name": "custom:cpf", "Value": cpf},
                    {"Name": "custom:nome", "Value": nome},
                    {"Name": "custom:data_nascimento", "Value": row["data_nascimento"]},
                ],
                TemporaryPassword=password,
                MessageAction="SUPPRESS"
            )
            print(f"Usuário {username} criado com sucesso.")

            client.admin_set_user_password(
                UserPoolId=user_pool_id,
                Username=username,
                Password=password,
                Permanent=True
            )
            print(f"Senha permanente definida para o usuário {username}.")

        except Exception as e:
            print(f"Erro ao processar o usuário {username}: {str(e)}")
