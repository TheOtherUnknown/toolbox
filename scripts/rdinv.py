import ldap3
pool = ldap3.ServerPool([ldap3.Server('auth1.csg.ius.edu'), ldap3.Server('auth2.csg.ius.edu')], ldap3.ROUND_ROBIN, active=True, exhaust=True) # Defines the pool of LDAP servers
conn = ldap3.Connection(pool, auto_bind=True) # Bind to the pool anonymously 
conn.search("cn=ng,cn=compat,dc=csg,dc=ius,dc=edu", '(objectclass=nisNetgroup)', 
attributes=['nisNetgroupTriple']) # Search the directory 
for element in conn.entries: 
  for attrib in element.nisNetgroupTriple:
      print(attrib.split(",")[0][1:])
