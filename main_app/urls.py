from django.urls import path
from . import views

urlpatterns = [
    path('search-ships/', views.search_ships, name='search_ships'),
    path('book-order/', views.book_order, name='book_order'),
    path('markup/', views.admin_markup, name='admin_markup'),
    path('profit-chart/', views.daily_profit_chart, name='daily_profit_chart'),
]
