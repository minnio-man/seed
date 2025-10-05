from django.contrib import admin
from django.urls import path
from . import views

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', views.home, name='home'),
    path('sum/', views.sum_view, name='sum'),
    path('health/', views.health_view, name='health'),
    path('publish/', views.publish_event_view, name='publish'),
]
