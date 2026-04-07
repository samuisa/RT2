from setuptools import find_packages, setup

package_name = 'fibonacci'

setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='root',
    maintainer_email='carmine.recchiuto@dibris.unige.it',
    description='TODO: Package description',
    license='TODO: License declaration',
    tests_require=['pytest'],
    entry_points={
    'console_scripts': [
        'fibonacci_server = fibonacci.basic_server:main',
        'fibonacci_client = fibonacci.basic_client:main',
        'fibonacci_server_2 = fibonacci.basic_server_2:main',
        'fibonacci_server_3 = fibonacci.action_server:main',
        'fibonacci_client_2 = fibonacci.action_client:main',
        'fibonacci_client_3 = fibonacci.cancel_client:main',
        'fibonacci_server_4 = fibonacci.action_server_2:main',
        'fibonacci_server_5 = fibonacci.action_server_3:main',
        ],
    }
)
