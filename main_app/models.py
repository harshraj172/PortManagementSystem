from django.db import models

class User(models.Model):
    userid = models.AutoField(db_column='UserID', primary_key=True)
    username = models.CharField(db_column='Username', max_length=50, unique=True)
    passwordhash = models.CharField(db_column='PasswordHash', max_length=255)
    usertype = models.CharField(db_column='UserType', max_length=10)

    class Meta:
        db_table = 'User'
        managed = False  # since we already have the table from schema.sql

    def __str__(self):
        return self.username
